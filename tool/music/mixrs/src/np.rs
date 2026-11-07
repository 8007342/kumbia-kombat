//! The few NumPy behaviours mix.py relies on, down to their rounding and edge rules.

use std::f64::consts::PI;

/// Python's round(): half to even.
pub fn py_round(x: f64) -> i64 {
    x.round_ties_even() as i64
}

/// Python's round(x, digits) on a float: the exact binary value, rounded in decimal.
pub fn round_to(x: f64, digits: usize) -> f64 {
    format!("{:.*}", digits, x).parse().unwrap_or(x)
}

/// np.hanning: symmetric.
pub fn hanning(m: usize) -> Vec<f64> {
    if m == 1 {
        return vec![1.0];
    }
    (0..m)
        .map(|n| {
            let k = 1 - m as i64 + 2 * n as i64;
            0.5 + 0.5 * (PI * k as f64 / (m - 1) as f64).cos()
        })
        .collect()
}

/// np.arange(start, stop, step): numpy steps by (start + step) - start.
pub fn arange(start: f64, stop: f64, step: f64) -> Vec<f64> {
    let len = ((stop - start) / step).ceil().max(0.0) as usize;
    let delta = (start + step) - start;
    (0..len).map(|i| start + i as f64 * delta).collect()
}

/// np.linspace with endpoints.
pub fn linspace(a: f64, b: f64, n: usize) -> Vec<f64> {
    let step = (b - a) / (n - 1) as f64;
    let mut out: Vec<f64> = (0..n).map(|i| a + i as f64 * step).collect();
    out[n - 1] = b;
    out
}

/// np.convolve(a, k, mode="same"), for a kernel no longer than the signal.
pub fn convolve_same(a: &[f64], k: &[f64]) -> Vec<f64> {
    assert!(k.len() <= a.len(), "kernel longer than signal");
    let n = k.len();
    let first = n - n / 2 - 1;
    (0..a.len())
        .map(|i| {
            let at = i + first; // the index in the full convolution
            let lo = (at + 1).saturating_sub(n);
            let hi = at.min(a.len() - 1);
            let mut sum = 0.0;
            for j in lo..=hi {
                sum += a[j] * k[at - j];
            }
            sum
        })
        .collect()
}

/// np.interp for increasing xp, with explicit outside values.
pub struct Interp<'a> {
    pub xp: &'a [f64],
    pub fp: &'a [f64],
    pub left: f64,
    pub right: f64,
}

impl Interp<'_> {
    pub fn at(&self, x: f64) -> f64 {
        let n = self.xp.len();
        if x < self.xp[0] {
            return self.left;
        }
        if x > self.xp[n - 1] {
            return self.right;
        }
        let j = self.xp.partition_point(|&v| v <= x).saturating_sub(1);
        if j >= n - 1 {
            return self.fp[n - 1];
        }
        if self.xp[j] == x {
            return self.fp[j];
        }
        let slope = (self.fp[j + 1] - self.fp[j]) / (self.xp[j + 1] - self.xp[j]);
        slope * (x - self.xp[j]) + self.fp[j]
    }
}

/// Plain np.interp: outside values hold the ends.
pub fn interp(x: f64, xp: &[f64], fp: &[f64]) -> f64 {
    Interp { xp, fp, left: fp[0], right: fp[fp.len() - 1] }.at(x)
}

/// np.argmax: the first of equal maxima.
pub fn argmax(v: &[f64]) -> usize {
    let mut best = 0;
    for (i, &x) in v.iter().enumerate() {
        if x > v[best] {
            best = i;
        }
    }
    best
}

pub fn mean(v: &[f64]) -> f64 {
    v.iter().sum::<f64>() / v.len() as f64
}

/// np.median.
pub fn median(v: &[f64]) -> f64 {
    let mut s = v.to_vec();
    s.sort_by(f64::total_cmp);
    let n = s.len();
    if n == 0 {
        f64::NAN
    } else if n % 2 == 1 {
        s[n / 2]
    } else {
        0.5 * (s[n / 2 - 1] + s[n / 2])
    }
}

/// np.percentile, linear.
pub fn percentile(v: &[f64], q: f64) -> f64 {
    let mut s = v.to_vec();
    s.sort_by(f64::total_cmp);
    let at = q / 100.0 * (s.len() - 1) as f64;
    let lo = at.floor() as usize;
    let hi = (lo + 1).min(s.len() - 1);
    s[lo] + (s[hi] - s[lo]) * (at - lo as f64)
}

/// np.unwrap.
pub fn unwrap(p: &[f64]) -> Vec<f64> {
    let mut out = p.to_vec();
    let mut correct = 0.0;
    for i in 1..p.len() {
        let dd = p[i] - p[i - 1];
        let mut m = (dd + PI).rem_euclid(2.0 * PI) - PI;
        if m == -PI && dd > 0.0 {
            m = PI;
        }
        let mut c = m - dd;
        if dd.abs() < PI {
            c = 0.0;
        }
        correct += c;
        out[i] = p[i] + correct;
    }
    out
}

/// A straight-line fit: slope and offset, as np.polyfit(x, y, 1).
pub fn polyfit1(x: &[f64], y: &[f64]) -> (f64, f64) {
    let mx = mean(x);
    let my = mean(y);
    let mut sxy = 0.0;
    let mut sxx = 0.0;
    for (a, b) in x.iter().zip(y) {
        sxy += (a - mx) * (b - my);
        sxx += (a - mx) * (a - mx);
    }
    let slope = sxy / sxx;
    (slope, my - slope * mx)
}

/// np.corrcoef(a, b)[0, 1].
pub fn corrcoef(a: &[f64], b: &[f64]) -> f64 {
    let (ma, mb) = (mean(a), mean(b));
    let (mut ab, mut aa, mut bb) = (0.0, 0.0, 0.0);
    for (x, y) in a.iter().zip(b) {
        ab += (x - ma) * (y - mb);
        aa += (x - ma) * (x - ma);
        bb += (y - mb) * (y - mb);
    }
    ab / (aa * bb).sqrt()
}

pub fn dot(a: &[f64], b: &[f64]) -> f64 {
    a.iter().zip(b).map(|(x, y)| x * y).sum()
}

/// mix.py's _unit on one vector.
pub fn unit(v: &[f64]) -> Vec<f64> {
    let norm = dot(v, v).sqrt().max(1e-9);
    v.iter().map(|x| x / norm).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn convolve_same_matches_numpy_alignment() {
        // np.convolve([1,2,3,4,5],[1,0,0,0],"same") is [2,3,4,5,0].
        assert_eq!(convolve_same(&[1., 2., 3., 4., 5.], &[1., 0., 0., 0.]), vec![2., 3., 4., 5., 0.]);
        // np.convolve([1,2,3,4,5],[1,1,1],"same") is [3,6,9,12,9].
        assert_eq!(convolve_same(&[1., 2., 3., 4., 5.], &[1., 1., 1.]), vec![3., 6., 9., 12., 9.]);
    }

    #[test]
    fn rounding_is_half_even() {
        assert_eq!(py_round(2.5), 2);
        assert_eq!(py_round(3.5), 4);
        assert_eq!(round_to(1.005, 2), 1.0); // 1.005 is just under in binary, as in Python
    }

    #[test]
    fn arange_counts_as_numpy_does() {
        assert_eq!(arange(-0.15, 0.1501, 0.003).len(), 101);
        assert_eq!(arange(-0.5, 0.5, 0.001).len(), 1000);
    }

    #[test]
    fn unwrap_and_fit() {
        let u = unwrap(&[3.0, -3.0, -1.0]);
        assert!((u[1] - (-3.0 + 2.0 * PI)).abs() < 1e-12);
        let (m, b) = polyfit1(&[0., 1., 2.], &[1., 3., 5.]);
        assert!((m - 2.).abs() < 1e-12 && (b - 1.).abs() < 1e-12);
    }
}
