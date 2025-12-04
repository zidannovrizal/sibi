"""Utility script to convert `.keras` models into `.tflite` format.

Usage (run from repository root):
    python tools/convert_keras_model/convert.py \
        --input assets/models/bima_model.keras \
        --output assets/models/bima_model.tflite
"""

from __future__ import annotations

import argparse
import json
import tempfile
import zipfile
from importlib import util as importlib_util
from pathlib import Path
from typing import Optional

import tensorflow as tf


class LegacyInputLayer(tf.keras.layers.InputLayer):
    """Backcompat layer that tolerates `batch_shape` configs."""

    def __init__(self, batch_shape=None, **kwargs):
        if batch_shape is not None and "batch_input_shape" not in kwargs:
            kwargs["batch_input_shape"] = tuple(batch_shape)
        super().__init__(**kwargs)

    @classmethod
    def from_config(cls, config: dict):
        batch_shape = config.pop("batch_shape", None)
        if batch_shape is not None and "batch_input_shape" not in config:
            config["batch_input_shape"] = tuple(batch_shape)
        return super().from_config(config)


CUSTOM_OBJECTS = {"InputLayer": LegacyInputLayer}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a Keras model file into a TensorFlow Lite model.",
    )
    parser.add_argument(
        "--input",
        "-i",
        type=Path,
        required=True,
        help="Path to the source `.keras` file or SavedModel directory.",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        required=True,
        help="Destination path for the generated `.tflite` file.",
    )
    parser.add_argument(
        "--optimize",
        choices=["default", "size", "latency", "none"],
        default="default",
        help="Optional optimization strategy to apply during conversion.",
    )
    parser.add_argument(
        "--representative-dataset",
        type=Path,
        default=None,
        help="Optional path to a Python module exposing `representative_dataset()`.",
    )
    parser.add_argument(
        "--safe-mode",
        action="store_true",
        help="Enable Keras safe mode when loading the model.",
    )
    parser.add_argument(
        "--legacy-ops",
        action="store_true",
        help=(
            "Restrict conversion to builtin ops only (for older runtimes such as "
            "tflite_flutter 0.11.0 / TFLite 2.11)."
        ),
    )
    return parser.parse_args()


def load_representative_dataset(module_path: Optional[Path]):
    if module_path is None:
        return None

    module_path = module_path.resolve()
    if not module_path.exists():
        raise FileNotFoundError(f"Representative dataset module not found: {module_path}")

    spec = importlib_util.spec_from_file_location("representative_dataset", module_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot import representative dataset from {module_path}")

    module = importlib_util.module_from_spec(spec)
    spec.loader.exec_module(module)

    if not hasattr(module, "representative_dataset"):
        raise AttributeError(
            "Module must define a callable named `representative_dataset`."
        )

    return module.representative_dataset


def load_model(input_path: Path, safe_mode: bool) -> tf.keras.Model:
    if input_path.is_dir():
        return tf.keras.models.load_model(
            str(input_path),
            compile=False,
            custom_objects=CUSTOM_OBJECTS,
        )

    if input_path.suffix != ".keras":
        raise ValueError("Only `.keras` archives or SavedModel directories are supported.")

    def _patch_config(config: dict):
        if isinstance(config, dict):
            if "batch_shape" in config and "batch_input_shape" not in config:
                config["batch_input_shape"] = config.pop("batch_shape")
            if "dtype" in config:
                config.pop("dtype")
            for value in list(config.values()):
                _patch_config(value)
        elif isinstance(config, list):
            for item in config:
                _patch_config(item)

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        with zipfile.ZipFile(input_path, "r") as archive:
            archive.extractall(tmp_path)

        config_path = tmp_path / "config.json"
        if config_path.exists():
            config_data = json.loads(config_path.read_text())
            _patch_config(config_data)
            config_path.write_text(json.dumps(config_data, indent=2))

        patched_path = tmp_path / "patched.keras"
        with zipfile.ZipFile(patched_path, "w") as archive:
            for file in tmp_path.rglob("*"):
                if file == patched_path:
                    continue
                archive.write(file, file.relative_to(tmp_path))

        return tf.keras.models.load_model(
            str(patched_path),
            compile=False,
            safe_mode=safe_mode,
            custom_objects=CUSTOM_OBJECTS,
        )


def convert_with_converter(
    converter: tf.lite.TFLiteConverter,
    output_path: Path,
    optimize: str,
    representative_dataset: Optional[Path],
    legacy_ops: bool,
) -> None:
    converter.experimental_enable_resource_variables = True
    if legacy_ops:
        converter._experimental_lower_tensor_list_ops = True  # pylint: disable=protected-access
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        converter._experimental_disable_per_channel = True  # pylint: disable=protected-access
        converter.allow_custom_ops = False
    else:
        converter._experimental_lower_tensor_list_ops = False  # pylint: disable=protected-access
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS,
        ]

    if optimize != "none":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

    if optimize == "size" and representative_dataset:
        converter.representative_dataset = load_representative_dataset(representative_dataset)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.int8
        converter.inference_output_type = tf.int8

    tflite_model = converter.convert()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(tflite_model)


def convert_model(
    input_path: Path,
    output_path: Path,
    optimize: str = "default",
    representative_dataset: Optional[Path] = None,
    safe_mode: bool = False,
    legacy_ops: bool = False,
) -> None:
    model = load_model(input_path, safe_mode=safe_mode)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    convert_with_converter(
        converter,
        output_path,
        optimize,
        representative_dataset,
        legacy_ops,
    )


def main() -> None:
    args = parse_args()
    convert_model(
        input_path=args.input,
        output_path=args.output,
        optimize=args.optimize,
        representative_dataset=args.representative_dataset,
        safe_mode=args.safe_mode,
        legacy_ops=args.legacy_ops,
    )
    print(f"Converted model saved to {args.output}")


if __name__ == "__main__":
    main()
