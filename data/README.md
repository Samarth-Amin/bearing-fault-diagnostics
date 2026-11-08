# Dataset Documentation: CWRU Bearing Data Center

This project utilizes benchmark vibration acceleration data provided by the **Case Western Reserve University (CWRU) Bearing Data Center**.

---

## 1. Test Rig Specifications
* **Motor:** 2-hp Reliance Electric induction motor.
* **Dynamometer:** Controls motor load (0 hp to 3 hp).
* **Test Bearings:**
  * **Drive End (DE):** SKF 6205-2RS JEM deep groove ball bearing.
  * **Fan End (FE):** SKF 6203-2RS JEM deep groove ball bearing.
* **Transducers:** Accelerometers mounted on the motor housing at Drive End (DE) and Fan End (FE).
* **Sampling Rate:** 48,000 samples/sec (48 kHz).

---

## 2. Directory Layout Expected by Pipeline

Due to file size limits on GitHub, `.mat` files are excluded via `.gitignore`. Place the raw MATLAB `.mat` files in the following directory hierarchy under `data/`:

```
data/
├── Healthy_data/
│   ├── 0hp.mat       # Baseline normal bearing @ ~1796 RPM (DE: X097)
│   └── 3hp.mat       # Baseline normal bearing @ ~1725 RPM (DE: X100)
├── 0hp/
│   └── 48k/
│       ├── 0.007/    (IR.mat, Ball.mat, OR.mat)
│       ├── 0.014/    (IR.mat, Ball.mat, OR.mat)
│       └── 0.021/    (IR.mat, Ball.mat, OR.mat)
└── 3hp/
    └── 48k/
        ├── 0.007/    (IR.mat, Ball.mat, OR.mat)
        ├── 0.014/    (IR.mat, Ball.mat, OR.mat)
        └── 0.021/    (IR.mat, Ball.mat, OR.mat)
```

---

## 3. Reference
* CWRU Bearing Data Center: [Case School of Engineering](https://engineering.case.edu/bearingdatacenter)
* Bearing Geometry for SKF 6205:
  * Number of balls ($N_b$) = 9
  * Ball diameter ($B_d$) = 7.94 mm (0.3126 in)
  * Pitch diameter ($P_d$) = 39.04 mm (1.537 in)
  * Contact angle ($\beta$) = $0^\circ$
