# Keras to TFLite Conversion

This utility converts the `.keras` model checked into `assets/models` into a `.tflite`
file that can be consumed by the Flutter app.

## Prerequisites

- Python 3.9-3.11 (TensorFlow 2.15 wheels are available for these versions)
- Install dependencies in a virtual environment:
  ```powershell
  python -m pip install -r tools/convert_keras_model/requirements.txt
  ```

## Convert the default model

> Run commands from the project root (`bima_app`).

```bash
python tools/convert_keras_model/convert.py \
  --input assets/models/bima_model.keras \
  --output assets/models/bima_model.tflite
```

> The converter enables Select TF Ops to support TensorList operations emitted by LSTM layers. On mobile you must bundle the TensorFlow Lite Flex delegate (e.g. add `tensorflow-lite-select-tf-ops` on Android).

## Optional quantization

To perform size-optimized conversion with a representative dataset:

1. Create a Python file that exposes a `representative_dataset()` generator.
2. Pass the file via `--representative-dataset`.

```bash
python tools/convert_keras_model/convert.py \
  --input assets/models/bima_model.keras \
  --output assets/models/bima_model_int8.tflite \
  --optimize size \
  --representative-dataset tools/convert_keras_model/representative_data.py
```

> If int8 quantization fails for a `.keras` file, export the model to a SavedModel first (`model.save('path', save_format='tf')`) and rerun the converter.

The generated `.tflite` file will be ready for loading by `TfliteService`.
