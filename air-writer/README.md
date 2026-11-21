# Air Writer

Write capital letters in the air with your index finger; the webcam reads them and builds words.

- Hand tracking: MediaPipe Hand Landmarker (runs in the browser).
- Letter recognition: a small CNN (33k parameters, int8 weights embedded in `index.html`)
  trained on 130,000 synthetic air-written letters, combined with a $P point-cloud matcher
  that also learns from your corrections.
- Retrain: `cd ml && python3 train.py` (needs `torch`, `numpy`), then paste `weights.json`
  into `index.html` at `const CNN_W=`.

Static site: deploy the `air-writer/` folder anywhere that serves HTTPS (camera access needs HTTPS).
