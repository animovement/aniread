#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

using namespace Rcpp;

// =============================================================================
// Compile-time constants
// =============================================================================

// Integer-scaled BT.601 luminance coefficients (Q8 fixed-point)
// 0.299 * 256 = 76.544 -> 77
// 0.587 * 256 = 150.272 -> 150
// 0.114 * 256 = 29.184 -> 29
// 77 + 150 + 29 = 256, so (77*R + 150*G + 29*B + 128) >> 8 is exact to uint8
static constexpr int kLumR = 77;
static constexpr int kLumG = 150;
static constexpr int kLumB = 29;

static inline uint8_t fast_luminance(uint8_t r, uint8_t g, uint8_t b) {
  return (uint8_t)((kLumR * r + kLumG * g + kLumB * b + 128) >> 8);
}

// =============================================================================
// Pre-allocated workspace -- eliminates per-frame heap allocations
// =============================================================================

struct FrameWorkspace {
  // Subsampled channel buffers
  std::vector<uint8_t> r, g, b, lum;
  // Floating-point luminance (spatial only)
  std::vector<double> lum_d;
  // Row buffer for one frame's metrics (written contiguously, then scattered
  // into column-major NumericMatrix)
  std::vector<double> row_buf;

  // Cache-line aligned histograms
  alignas(64) uint32_t hist_r[256];
  alignas(64) uint32_t hist_g[256];
  alignas(64) uint32_t hist_b[256];
  alignas(64) uint32_t hist_lum[256];

  void resize(int n_sub, int n_metrics) {
    r.resize(n_sub);
    g.resize(n_sub);
    b.resize(n_sub);
    lum.resize(n_sub);
    lum_d.resize(n_sub);
    row_buf.resize(n_metrics);
  }
};

// =============================================================================
// Stats from a pre-built histogram (no raw data scan needed)
// =============================================================================

static void stats_from_histogram(
    const uint32_t* hist,
    int             n,
    double*         out   // 9 values: mean, sd, median, min, max, q05, q95, skew, kurt
) {
  // -- mean --
  double mu = 0.0;
  for (int v = 0; v < 256; v++) mu += (double)v * hist[v];
  mu /= n;

  // -- variance, skew, kurtosis accumulators --
  double sum2 = 0.0, sum3 = 0.0, sum4 = 0.0;
  for (int v = 0; v < 256; v++) {
    if (!hist[v]) continue;
    double d   = v - mu;
    double d2  = d * d;
    double hd2 = hist[v] * d2;
    sum2 += hd2;
    sum3 += hd2 * d;
    sum4 += hd2 * d2;
  }
  double sd = (n > 1) ? std::sqrt(sum2 / (n - 1)) : NA_REAL;

  // -- min / max (scan from edges inward) --
  int vmin = 0, vmax = 255;
  while (vmin < 256 && !hist[vmin]) vmin++;
  while (vmax >= 0  && !hist[vmax]) vmax--;

  // -- quantile helper --
  auto quant = [&](double p) -> double {
    double   target = p * (n - 1);
    uint32_t cum    = 0;
    for (int v = 0; v < 256; v++) {
      if (!hist[v]) continue;
      uint32_t prev = cum;
      cum += hist[v];
      if ((double)cum > target) {
        double frac = ((double)prev < target && hist[v] > 1)
          ? (target - (double)prev) / hist[v]
          : 0.0;
        return v + frac;
      }
    }
    return (double)vmax;
  };

  // -- median (specialised for integer histogram) --
  double med;
  if (n % 2 != 0) {
    uint32_t cum = 0, target = (uint32_t)(n / 2);
    med = 0.0;
    for (int v = 0; v < 256; v++) {
      cum += hist[v];
      if (cum > target) { med = (double)v; break; }
    }
  } else {
    uint32_t cum = 0;
    int lo = -1, hi = -1;
    uint32_t t_lo = (uint32_t)(n / 2 - 1);
    uint32_t t_hi = (uint32_t)(n / 2);
    for (int v = 0; v < 256; v++) {
      cum += hist[v];
      if (lo < 0 && cum > t_lo) lo = v;
      if (hi < 0 && cum > t_hi) hi = v;
      if (lo >= 0 && hi >= 0)   break;
    }
    med = (lo + hi) / 2.0;
  }

  out[0] = mu;
  out[1] = sd;
  out[2] = med;
  out[3] = (double)vmin;
  out[4] = (double)vmax;
  out[5] = quant(0.05);
  out[6] = quant(0.95);
  out[7] = (sd > 0.0) ? (sum3 / n) / (sd * sd * sd)            : NA_REAL;
  out[8] = (sd > 0.0) ? (sum4 / n) / (sd * sd * sd * sd) - 3.0 : NA_REAL;
}

// =============================================================================
// Per-frame worker -- zero allocations, fused data passes
// =============================================================================

static void compute_one_frame(
    const uint8_t*          raw,
    int                     n_pixels,
    const int*              sub_idx,   // 0-based, contiguous array
    int                     n_sub,
    bool                    is_sequential,
    const int*              col_sub,
    const int*              row_sub,
    bool                    do_rgb,
    bool                    do_luminance,
    bool                    do_hsv,
    bool                    do_activity,
    bool                    do_spatial,
    int                     active_threshold,
    FrameWorkspace&         ws,
    double*                 out        // contiguous row buffer
) {
  int pos = 0;
  const bool need_lum_sub = do_luminance || do_spatial;
  const bool need_channels = do_rgb || do_hsv || do_spatial || need_lum_sub;

  // ==========================================================================
  // PASS 1 (subsampled pixels): extract channels + build histograms in one go
  // ==========================================================================

  if (need_channels) {
    if (do_rgb)       { std::memset(ws.hist_r,   0, 256 * sizeof(uint32_t));
                        std::memset(ws.hist_g,   0, 256 * sizeof(uint32_t));
                        std::memset(ws.hist_b,   0, 256 * sizeof(uint32_t)); }
    if (do_luminance) { std::memset(ws.hist_lum, 0, 256 * sizeof(uint32_t)); }

    if (is_sequential) {
      // --- Fast path: sequential RGB24 stream, no gather needed ---
      const uint8_t* p = raw;
      for (int i = 0; i < n_sub; i++, p += 3) {
        uint8_t rv = p[0], gv = p[1], bv = p[2];
        ws.r[i] = rv;
        ws.g[i] = gv;
        ws.b[i] = bv;
        if (do_rgb) {
          ws.hist_r[rv]++;
          ws.hist_g[gv]++;
          ws.hist_b[bv]++;
        }
        if (need_lum_sub) {
          uint8_t l = fast_luminance(rv, gv, bv);
          ws.lum[i] = l;
          if (do_luminance) ws.hist_lum[l]++;
        }
      }
    } else {
      // --- Scattered path: gather by index ---
      for (int i = 0; i < n_sub; i++) {
        const uint8_t* p = raw + 3 * sub_idx[i];
        uint8_t rv = p[0], gv = p[1], bv = p[2];
        ws.r[i] = rv;
        ws.g[i] = gv;
        ws.b[i] = bv;
        if (do_rgb) {
          ws.hist_r[rv]++;
          ws.hist_g[gv]++;
          ws.hist_b[bv]++;
        }
        if (need_lum_sub) {
          uint8_t l = fast_luminance(rv, gv, bv);
          ws.lum[i] = l;
          if (do_luminance) ws.hist_lum[l]++;
        }
      }
    }
  }

  // ==========================================================================
  // RGB stats (histograms already built)
  // ==========================================================================
  if (do_rgb) {
    stats_from_histogram(ws.hist_r, n_sub, out + pos); pos += 9;
    stats_from_histogram(ws.hist_g, n_sub, out + pos); pos += 9;
    stats_from_histogram(ws.hist_b, n_sub, out + pos); pos += 9;
  }

  // ==========================================================================
  // Luminance stats (histogram already built)
  // ==========================================================================
  if (do_luminance) {
    stats_from_histogram(ws.hist_lum, n_sub, out + pos); pos += 9;
  }

  // ==========================================================================
  // HSV -- fused saturation/value accumulators + circular hue
  // ==========================================================================
  if (do_hsv) {
    double sat_sum = 0.0, val_sum = 0.0, sat_sum2 = 0.0, val_sum2 = 0.0;
    double sin_sum = 0.0, cos_sum = 0.0;
    int    n_active_hsv = 0;
    const double thresh_v = active_threshold / 255.0;
    const double inv255 = 1.0 / 255.0;

    for (int i = 0; i < n_sub; i++) {
      double rv = ws.r[i] * inv255;
      double gv = ws.g[i] * inv255;
      double bv = ws.b[i] * inv255;

      double vv, mn;
      if (rv >= gv) {
        vv = (rv >= bv) ? rv : bv;
        mn = (gv <= bv) ? gv : bv;
      } else {
        vv = (gv >= bv) ? gv : bv;
        mn = (rv <= bv) ? rv : bv;
      }

      double delta = vv - mn;
      double sv    = (vv > 0.0) ? delta / vv : 0.0;

      sat_sum  += sv;       sat_sum2 += sv * sv;
      val_sum  += vv;       val_sum2 += vv * vv;

      if (vv > thresh_v && delta > 0.0) {
        double hv;
        if (vv == rv) {
          hv = 60.0 * ((gv - bv) / delta);
          if (hv < 0.0) hv += 360.0;
        } else if (vv == gv) {
          hv = 60.0 * ((bv - rv) / delta) + 120.0;
        } else {
          hv = 60.0 * ((rv - gv) / delta) + 240.0;
        }
        double rad = hv * (M_PI / 180.0);
        sin_sum += std::sin(rad);
        cos_sum += std::cos(rad);
        n_active_hsv++;
      }
    }

    double inv_n   = 1.0 / n_sub;
    double sat_mu  = sat_sum * inv_n;
    double val_mu  = val_sum * inv_n;
    double sat_var = (n_sub > 1) ? (sat_sum2 - n_sub * sat_mu * sat_mu) / (n_sub - 1) : 0.0;
    double val_var = (n_sub > 1) ? (val_sum2 - n_sub * val_mu * val_mu) / (n_sub - 1) : 0.0;

    out[pos++] = sat_mu;
    out[pos++] = (sat_var > 0.0) ? std::sqrt(sat_var) : 0.0;
    out[pos++] = val_mu;
    out[pos++] = (val_var > 0.0) ? std::sqrt(val_var) : 0.0;

    if (n_active_hsv > 1) {
      double inv_a = 1.0 / n_active_hsv;
      double sc1   = sin_sum * inv_a;
      double sc2   = cos_sum * inv_a;
      double conc  = std::sqrt(sc1 * sc1 + sc2 * sc2);
      out[pos++]   = std::atan2(sc1, sc2) * (180.0 / M_PI);
      out[pos++]   = conc;
      out[pos++]   = (conc > 0.0 && conc < 1.0)
        ? std::sqrt(-2.0 * std::log(conc)) * (180.0 / M_PI)
        : 0.0;
    } else {
      out[pos++] = NA_REAL;
      out[pos++] = NA_REAL;
      out[pos++] = NA_REAL;
    }
  }

  // ==========================================================================
  // Activity -- integer luminance over ALL pixels, 4x unrolled
  // ==========================================================================
  if (do_activity) {
    int n_active = 0;
    const int thresh = active_threshold;
    const int n4 = (n_pixels / 4) * 4;
    const uint8_t* p = raw;

    // Compare in scaled integer domain to avoid per-pixel shift.
    // fast_luminance: (77R + 150G + 29B + 128) >> 8  >  thresh
    // equivalent to:   77R + 150G + 29B  >  (thresh << 8) - 128
    const int thresh_scaled = (thresh << 8) - 128;

    for (int i = 0; i < n4; i += 4) {
      int l0 = kLumR * p[0]  + kLumG * p[1]  + kLumB * p[2];
      int l1 = kLumR * p[3]  + kLumG * p[4]  + kLumB * p[5];
      int l2 = kLumR * p[6]  + kLumG * p[7]  + kLumB * p[8];
      int l3 = kLumR * p[9]  + kLumG * p[10] + kLumB * p[11];
      n_active += (l0 > thresh_scaled)
               +  (l1 > thresh_scaled)
               +  (l2 > thresh_scaled)
               +  (l3 > thresh_scaled);
      p += 12;
    }
    for (int i = n4; i < n_pixels; i++, p += 3) {
      int l = kLumR * p[0] + kLumG * p[1] + kLumB * p[2];
      n_active += (l > thresh_scaled);
    }

    out[pos++] = (double)n_active;
    out[pos++] = (double)n_active / n_pixels;
  }

  // ==========================================================================
  // Spatial -- luminance-weighted centroid + spread (subsampled)
  // ==========================================================================
  if (do_spatial) {
    double wsum = 0.0, wcx = 0.0, wcy = 0.0;

    for (int i = 0; i < n_sub; i++) {
      double lv;
      if (need_lum_sub) {
        lv = (double)ws.lum[i];
      } else {
        lv = fast_luminance(ws.r[i], ws.g[i], ws.b[i]);
      }
      ws.lum_d[i] = lv;
      double w = (lv > active_threshold) ? lv - active_threshold : 0.0;
      wsum += w;
      wcx  += w * col_sub[i];
      wcy  += w * row_sub[i];
    }

    if (wsum > 0.0) {
      double inv_w = 1.0 / wsum;
      double cx = wcx * inv_w, cy = wcy * inv_w;
      double sx = 0.0, sy = 0.0;
      for (int i = 0; i < n_sub; i++) {
        double w  = (ws.lum_d[i] > active_threshold) ? ws.lum_d[i] - active_threshold : 0.0;
        double dx = col_sub[i] - cx;
        double dy = row_sub[i] - cy;
        sx += w * dx * dx;
        sy += w * dy * dy;
      }
      out[pos++] = cx;
      out[pos++] = cy;
      out[pos++] = std::sqrt(sx * inv_w);
      out[pos++] = std::sqrt(sy * inv_w);
    } else {
      out[pos++] = NA_REAL;
      out[pos++] = NA_REAL;
      out[pos++] = NA_REAL;
      out[pos++] = NA_REAL;
    }
  }
}

// =============================================================================
// Exported entry point
// =============================================================================

//' Compute metrics for a buffer of frames
//'
//' Internal C++ worker called by [read_frame_metrics_full()]. Not intended for
//' direct use.
//'
//' @param buffer Raw vector containing one or more complete RGB24 frames.
//' @param n_frames Number of complete frames in `buffer`.
//' @param n_pixels Pixels per frame (`width * height`).
//' @param subsample_idx 1-based integer vector of pixel indices.
//' @param do_rgb,do_luminance,do_hsv,do_activity,do_spatial Logical flags.
//' @param active_threshold Integer luminance threshold (0--255).
//' @param px_col,px_row 1-based integer coordinate vectors, length `n_pixels`.
//'   Pass `integer(0)` when `do_spatial = FALSE`.
//' @param n_metrics Number of metric columns (excluding `time`).
//'
//' @return Numeric matrix with `n_frames` rows and `n_metrics` columns.
//'
//' @keywords internal
//' @export
// [[Rcpp::export]]
NumericMatrix compute_buffer_metrics_cpp(
    RawVector     buffer,
    int           n_frames,
    int           n_pixels,
    IntegerVector subsample_idx,
    bool          do_rgb,
    bool          do_luminance,
    bool          do_hsv,
    bool          do_activity,
    bool          do_spatial,
    int           active_threshold,
    IntegerVector px_col,
    IntegerVector px_row,
    int           n_metrics
) {
  const Rbyte* raw_buf = buffer.begin();
  const int    bpf     = n_pixels * 3;
  const int    n_sub   = subsample_idx.size();

  // -- Convert 1-based -> 0-based indices once --------------------------------
  std::vector<int> sub_idx(n_sub);
  bool is_sequential = (n_sub == n_pixels);
  for (int i = 0; i < n_sub; i++) {
    sub_idx[i] = subsample_idx[i] - 1;
    if (is_sequential && sub_idx[i] != i) is_sequential = false;
  }

  // -- Pre-compute spatial coordinate sub-arrays once -------------------------
  std::vector<int> col_sub, row_sub;
  if (do_spatial) {
    col_sub.resize(n_sub);
    row_sub.resize(n_sub);
    for (int i = 0; i < n_sub; i++) {
      col_sub[i] = px_col[sub_idx[i]];
      row_sub[i] = px_row[sub_idx[i]];
    }
  }

  // -- Allocate workspace ONCE for all frames ---------------------------------
  FrameWorkspace ws;
  ws.resize(n_sub, n_metrics);

  NumericMatrix result(n_frames, n_metrics);

  for (int f = 0; f < n_frames; f++) {
    const uint8_t* frame_raw = (const uint8_t*)(raw_buf + (size_t)f * bpf);

    // Zero the row buffer (so unset slots become 0 / NA as appropriate)
    std::memset(ws.row_buf.data(), 0, n_metrics * sizeof(double));

    // Compute into contiguous row buffer
    compute_one_frame(
      frame_raw, n_pixels,
      sub_idx.data(), n_sub, is_sequential,
      do_spatial ? col_sub.data() : nullptr,
      do_spatial ? row_sub.data() : nullptr,
      do_rgb, do_luminance, do_hsv, do_activity, do_spatial,
      active_threshold,
      ws,
      ws.row_buf.data()
    );

    // Scatter into column-major NumericMatrix
    for (int c = 0; c < n_metrics; c++) {
      result(f, c) = ws.row_buf[c];
    }
  }

  return result;
}