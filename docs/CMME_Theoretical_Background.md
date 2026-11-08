# Condition Monitoring & Machinery Diagnostics: Theoretical Background

This technical reference details the mathematical and mechanical principles underlying the vibration-based Condition-Based Maintenance (CBM) pipeline.

---

## 1. Kinematic Defect Frequencies in Rolling Element Bearings

When a rolling element impacts a localized defect (micro-crack or spall), a transient shock impulse is generated. Based on epicyclic bearing kinematics, the recurrence rates of these impacts are governed by bearing geometry and rotational speed ($f_r$ in Hz):

$$\gamma = \frac{B_d}{P_d} \cos\beta$$

where:
* $N_b$ = Number of rolling elements (balls) = $9$
* $B_d$ = Ball diameter = $7.94\text{ mm}$
* $P_d$ = Pitch circle diameter = $39.04\text{ mm}$
* $\beta$ = Contact angle = $0^\circ$ ($\cos\beta = 1.0$)
* $\gamma \approx \frac{7.94}{39.04} \approx 0.20338$

### Characteristic Defect Frequencies:
1. **Ball Pass Frequency Outer Race (BPFO):**
   $$\text{BPFO} = \frac{N_b \cdot f_r}{2} (1 - \gamma) \approx 3.585 \times f_r$$
2. **Ball Pass Frequency Inner Race (BPFI):**
   $$\text{BPFI} = \frac{N_b \cdot f_r}{2} (1 + \gamma) \approx 5.415 \times f_r$$
3. **Ball Spin Frequency (BSF):**
   $$\text{BSF} = \frac{P_d \cdot f_r}{2 B_d} (1 - \gamma^2) \approx 2.357 \times f_r$$
   *(Note: A rolling element defect strikes both the inner and outer raceways, producing impacts at $2 \times \text{BSF} \approx 4.714 \times f_r$.)*
4. **Fundamental Train Frequency (FTF / Cage Frequency):**
   $$\text{FTF} = \frac{f_r}{2} (1 - \gamma) \approx 0.398 \times f_r$$

---

## 2. Why Conventional Direct FFT Fails for Incipient Bearing Faults

Incipient localized defects (e.g., $0.007"$) generate micro-impacts of very short duration ($\approx 10\text{–}100\ \mu\text{s}$). In the frequency domain:
1. Short-duration impulses possess **very low energy** spread across an extremely broad frequency band.
2. The impacts excite the **structural resonance modes** of the bearing housing and machine structure (typically $2\text{–}10\text{ kHz}$).
3. In the low-frequency direct FFT spectrum ($0\text{–}1000\text{ Hz}$), high-energy rotational vibration components (unbalance at $1X$, shaft misalignment at $2X$, electrical line frequencies at 50/60 Hz) dominate the dynamic range, completely drowning out the defect repetition lines.

---

## 3. High-Frequency Resonance Technique (HFRT) & Hilbert Demodulation

Bearing impact vibration is mathematically modeled as an **Amplitude Modulated (AM)** signal:
$$x(t) = \left[1 + \sum_{k} A_k \cos(2\pi k f_{\text{fault}} t)\right] \cdot \cos(2\pi f_c t)$$
where $f_c$ is the structural resonance carrier frequency and $f_{\text{fault}}$ is the defect repetition frequency (BPFO, BPFI).

### The Hilbert Transform Demodulation Procedure:
1. The **Analytic Signal** $z(t)$ is formed by combining the real signal with its 90-degree phase-shifted Hilbert transform:
   $$z(t) = x(t) + j \mathcal{H}\{x(t)\}$$
2. The **Instantaneous Amplitude Envelope** $e(t)$ is extracted:
   $$e(t) = |z(t)| = \sqrt{x^2(t) + [\mathcal{H}\{x(t)\}]^2}$$
3. Computing the **Fourier Transform of $e(t)$** removes the carrier $f_c$ and shifts the modulation signature back down to baseband ($0\text{–}500\text{ Hz}$), revealing discrete spectral spikes at $1\times, 2\times, 3\times f_{\text{fault}}$.

---

## 4. Failure Mode Characteristics & Modulation Mechanics

* **Outer Race Fault:** The outer race is fixed in the housing and positioned at 6 o'clock (directly in the radial load zone). Every ball strikes the defect with constant radial preload, producing unmodulated, uniform shock trains with strong harmonics: $1\times, 2\times, 3\times\text{BPFO}$.
* **Inner Race Fault:** The defect rotates with the shaft through the stationary radial load zone once per revolution. This creates amplitude modulation at the shaft speed $f_r$, generating distinct **modulation sidebands** flanking the defect frequency: $\text{BPFI} \pm k \cdot f_r$.
* **Ball Fault:** The ball spins around its own axis at BSF while revolving around the pitch circle at FTF. It experiences 3D orientation precession and gyroscopic slip, meaning the defect strikes raceways at non-constant angles and often outside the maximum load zone. This causes energy dispersion across multiple sidebands, making full-bandwidth envelope detection ineffective without narrow bandpass resonance pre-filtering.
