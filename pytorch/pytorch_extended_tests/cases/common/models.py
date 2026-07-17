"""Small fixed models shared by the learning cases."""

from __future__ import annotations

import math
from typing import Any

from config.suite_config import MODEL_ARCHITECTURES


def build_linear_classifier() -> Any:
    """Build the small linear classifier used by the Level 0 demo."""

    import torch

    architecture = MODEL_ARCHITECTURES["linear"]

    class FixedLinearClassifier(torch.nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.linear = torch.nn.Linear(
                int(architecture["input_features"]),
                int(architecture["output_features"]),
            )

        def forward(self, value: Any, *, return_activations: bool = False) -> Any:
            logits = self.linear(value)
            if return_activations:
                return logits, {"logits": logits}
            return logits

    return FixedLinearClassifier()


def build_mlp() -> Any:
    """Build the MLP whose parameter names match the generated initial state."""

    import torch

    architecture = MODEL_ARCHITECTURES["mlp"]

    class FixedMLP(torch.nn.Module):
        def __init__(self) -> None:
            super().__init__()
            dimensions = (
                architecture["input_features"],
                *architecture["hidden_features"],
                architecture["output_features"],
            )
            self.layers = torch.nn.ModuleList(
                torch.nn.Linear(input_size, output_size)
                for input_size, output_size in zip(dimensions, dimensions[1:])
            )

        def forward(self, value: Any, *, return_activations: bool = False) -> Any:
            activations: dict[str, Any] = {}
            current = value
            for index, layer in enumerate(self.layers):
                current = layer(current)
                activations[f"linear_{index}"] = current
                if index + 1 != len(self.layers):
                    current = torch.relu(current)
                    activations[f"relu_{index}"] = current
            if return_activations:
                return current, activations
            return current

    return FixedMLP()


def build_cnn() -> Any:
    """Build the small CNN used by block and image-workload cases."""

    import torch

    architecture = MODEL_ARCHITECTURES["cnn"]
    input_channels, first_channels, second_channels = architecture["channels"]

    class FixedCNN(torch.nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.features = torch.nn.Sequential(
                torch.nn.Conv2d(input_channels, first_channels, kernel_size=3, padding=1),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
                torch.nn.Conv2d(first_channels, second_channels, kernel_size=3, padding=1),
                torch.nn.ReLU(),
                torch.nn.MaxPool2d(kernel_size=2),
            )
            flattened_features = second_channels * 7 * 7
            self.classifier = torch.nn.Sequential(
                torch.nn.Linear(
                    flattened_features,
                    architecture["classifier_hidden_features"],
                ),
                torch.nn.ReLU(),
                torch.nn.Linear(
                    architecture["classifier_hidden_features"],
                    architecture["classes"],
                ),
            )

        def forward(self, value: Any, *, return_activations: bool = False) -> Any:
            activations: dict[str, Any] = {}
            current = value
            activation_names = (
                "conv_0",
                "relu_0",
                "pool_0",
                "conv_1",
                "relu_1",
                "pool_1",
            )
            for name, layer in zip(activation_names, self.features):
                current = layer(current)
                activations[name] = current

            current = torch.flatten(current, start_dim=1)
            activations["flattened"] = current
            current = self.classifier[0](current)
            activations["classifier_linear_0"] = current
            current = self.classifier[1](current)
            activations["classifier_relu_0"] = current
            current = self.classifier[2](current)
            activations["logits"] = current

            if return_activations:
                return current, activations
            return current

    return FixedCNN()


def build_attention_block() -> Any:
    """Build a small residual multi-head attention classifier."""

    import torch

    architecture = MODEL_ARCHITECTURES["attention"]
    embedding_size = int(architecture["embedding_size"])
    head_count = int(architecture["heads"])
    head_size = embedding_size // head_count

    class FixedAttentionBlock(torch.nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.q_proj = torch.nn.Linear(embedding_size, embedding_size)
            self.k_proj = torch.nn.Linear(embedding_size, embedding_size)
            self.v_proj = torch.nn.Linear(embedding_size, embedding_size)
            self.out_proj = torch.nn.Linear(embedding_size, embedding_size)
            self.norm = torch.nn.LayerNorm(embedding_size)
            self.classifier = torch.nn.Linear(embedding_size, architecture["classes"])

        def _split_heads(self, value: Any) -> Any:
            batch_size, sequence_length, _ = value.shape
            return value.reshape(
                batch_size,
                sequence_length,
                head_count,
                head_size,
            ).transpose(1, 2)

        def forward(
            self,
            value: Any,
            padding_mask: Any,
            *,
            return_activations: bool = False,
        ) -> Any:
            query = self._split_heads(self.q_proj(value))
            key = self._split_heads(self.k_proj(value))
            projected_value = self._split_heads(self.v_proj(value))

            scores = torch.matmul(query, key.transpose(-2, -1)) / math.sqrt(head_size)
            key_mask = padding_mask[:, None, None, :]
            scores = scores.masked_fill(key_mask, torch.finfo(scores.dtype).min)
            weights = torch.softmax(scores, dim=-1)
            attended = torch.matmul(weights, projected_value)
            attended = attended.transpose(1, 2).contiguous().reshape(value.shape)

            projected = self.out_proj(attended)
            normalised = self.norm(value + projected)
            valid_tokens = (~padding_mask).to(dtype=normalised.dtype).unsqueeze(-1)
            pooled = (normalised * valid_tokens).sum(dim=1) / valid_tokens.sum(dim=1)
            logits = self.classifier(pooled)

            if return_activations:
                return logits, {
                    "query": query,
                    "key": key,
                    "value": projected_value,
                    "attention_scores": scores,
                    "attention_weights": weights,
                    "attended": attended,
                    "projected": projected,
                    "normalised": normalised,
                    "pooled": pooled,
                }
            return logits

    return FixedAttentionBlock()


def build_sms_transformer() -> Any:
    """Build the small Transformer used by the SMS workload."""

    import torch

    architecture = MODEL_ARCHITECTURES["sms_transformer"]
    sequence_length = int(architecture["sequence_length"])
    embedding_size = int(architecture["embedding_size"])
    vocabulary_size = int(architecture["vocabulary_size"])

    class FixedSMSTransformer(torch.nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.token_embedding = torch.nn.Embedding(
                vocabulary_size,
                embedding_size,
                padding_idx=0,
            )
            self.position_embedding = torch.nn.Embedding(
                sequence_length,
                embedding_size,
            )
            layer = torch.nn.TransformerEncoderLayer(
                d_model=embedding_size,
                nhead=int(architecture["heads"]),
                dim_feedforward=int(architecture["feedforward_size"]),
                dropout=float(architecture["dropout"]),
                activation=str(architecture["activation"]),
                batch_first=True,
                norm_first=bool(architecture["norm_first"]),
            )
            try:
                self.encoder = torch.nn.TransformerEncoder(
                    layer,
                    num_layers=int(architecture["layers"]),
                    enable_nested_tensor=False,
                )
            except TypeError:
                # Older PyTorch releases do not expose the nested-tensor switch
                # The ordinary padded path is still selected by the Boolean mask
                self.encoder = torch.nn.TransformerEncoder(
                    layer,
                    num_layers=int(architecture["layers"]),
                )
            self.final_norm = torch.nn.LayerNorm(embedding_size)
            self.classifier = torch.nn.Linear(
                embedding_size,
                int(architecture["classes"]),
            )

        def forward(
            self,
            input_ids: Any,
            attention_mask: Any,
            *,
            return_activations: bool = False,
        ) -> Any:
            batch_size, current_length = input_ids.shape
            if current_length > sequence_length:
                raise ValueError(
                    f"Input sequence length {current_length} exceeds {sequence_length}"
                )

            positions = torch.arange(
                current_length,
                device=input_ids.device,
                dtype=torch.int64,
            ).unsqueeze(0).expand(batch_size, -1)
            embedded = self.token_embedding(input_ids) + self.position_embedding(positions)
            padding_mask = ~attention_mask
            encoded = self.encoder(
                embedded,
                src_key_padding_mask=padding_mask,
            )
            normalised = self.final_norm(encoded)
            valid_tokens = attention_mask.to(dtype=normalised.dtype).unsqueeze(-1)
            pooled = (normalised * valid_tokens).sum(dim=1) / valid_tokens.sum(dim=1)
            logits = self.classifier(pooled)

            if return_activations:
                return logits, {
                    "embedded": embedded,
                    "encoded": encoded,
                    "normalised": normalised,
                    "pooled": pooled,
                }
            return logits

    return FixedSMSTransformer()

