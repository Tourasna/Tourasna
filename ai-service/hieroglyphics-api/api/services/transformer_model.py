"""
Transformer architecture for hieroglyphic sequence translation.

Mirrors the HieroglyphTranslator class used during training in
02_sequence_translation.ipynb. The saved checkpoint (best_translator.pth)
stores only the state_dict, so we need this class definition to
re-instantiate the model before loading weights.

Hyperparameters come from metadata.json:
  d_model=256, nhead=8, encoder_layers=4, decoder_layers=4,
  src_vocab_size=1333, tgt_vocab_size=8000
"""
from __future__ import annotations

import math

import torch
import torch.nn as nn


class PositionalEncoding(nn.Module):
    """
    Sinusoidal positional encoding, as in "Attention is All You Need" (Vaswani et al., 2017).
    Adds position information to token embeddings so the transformer knows order.
    """

    def __init__(self, d_model: int, dropout: float = 0.1, max_len: int = 300) -> None:
        super().__init__()
        self.dropout = nn.Dropout(p=dropout)

        pe = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len, dtype=torch.float).unsqueeze(1)
        div_term = torch.exp(
            torch.arange(0, d_model, 2).float() * (-math.log(10000.0) / d_model)
        )
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        # Register as buffer so it moves with .to(device) but isn't trained
        self.register_buffer("pe", pe.unsqueeze(0))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x + self.pe[:, : x.size(1)]
        return self.dropout(x)


class HieroglyphTranslator(nn.Module):
    """
    Encoder-decoder Transformer that translates a sequence of Gardiner codes
    (source) into a sequence of English BPE tokens (target).

    Token convention:
      0 = <pad>
      1 = <bos> (beginning of sequence)
      2 = <eos> (end of sequence)
    """

    def __init__(
        self,
        src_vocab_size: int,
        tgt_vocab_size: int,
        d_model: int = 256,
        nhead: int = 8,
        num_encoder_layers: int = 4,
        num_decoder_layers: int = 4,
        dim_ff: int = 1024,
        dropout: float = 0.1,
    ) -> None:
        super().__init__()
        self.d_model = d_model

        # Token embeddings - padding_idx=0 zeros out gradients for <pad>
        self.src_embedding = nn.Embedding(src_vocab_size, d_model, padding_idx=0)
        self.tgt_embedding = nn.Embedding(tgt_vocab_size, d_model, padding_idx=0)

        # Shared positional encoding for both encoder and decoder
        self.pos_encoder = PositionalEncoding(d_model, dropout, max_len=300)

        # Core transformer. batch_first=True makes shapes (batch, seq, dim)
        # instead of (seq, batch, dim), which is easier to reason about.
        self.transformer = nn.Transformer(
            d_model=d_model,
            nhead=nhead,
            num_encoder_layers=num_encoder_layers,
            num_decoder_layers=num_decoder_layers,
            dim_feedforward=dim_ff,
            dropout=dropout,
            batch_first=True,
        )

        # Project decoder output back to target vocabulary size for softmax
        self.output_proj = nn.Linear(d_model, tgt_vocab_size)

    def forward(self, src: torch.Tensor, tgt: torch.Tensor) -> torch.Tensor:
        """
        Args:
            src: (batch, src_len) LongTensor of source token IDs
            tgt: (batch, tgt_len) LongTensor of target token IDs (teacher forcing)
        Returns:
            logits: (batch, tgt_len, tgt_vocab_size)
        """
        # Causal mask for the decoder so it can't peek at future tokens
        tgt_mask = nn.Transformer.generate_square_subsequent_mask(tgt.size(1)).to(
            src.device
        )
        # Padding masks - True where tokens should be ignored
        src_padding_mask = src == 0
        tgt_padding_mask = tgt == 0

        # Scale embeddings by sqrt(d_model) (original paper convention)
        src_emb = self.pos_encoder(self.src_embedding(src) * math.sqrt(self.d_model))
        tgt_emb = self.pos_encoder(self.tgt_embedding(tgt) * math.sqrt(self.d_model))

        output = self.transformer(
            src_emb,
            tgt_emb,
            tgt_mask=tgt_mask,
            src_key_padding_mask=src_padding_mask,
            tgt_key_padding_mask=tgt_padding_mask,
        )
        return self.output_proj(output)