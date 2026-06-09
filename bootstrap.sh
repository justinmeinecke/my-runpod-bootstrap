#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

MODE="${MODE:-image}"
echo "Mode: $MODE"

if [[ "$MODE" != "image" && "$MODE" != "video" && "$MODE" != "both" ]]; then
  echo "❌ Invalid MODE: $MODE"
  exit 1
fi
# -------------------------
# BASIC PACKAGES
# -------------------------
apt-get update -qq
apt-get install -y -qq unzip wget curl git ffmpeg


# -------------------------
# COMFYUI SETUP (IMAGE / VIDEO MODES ONLY)
# -------------------------
echo "Detecting ComfyUI location..."

if [ -d "/workspace/runpod-slim/ComfyUI/models" ]; then
    COMFY_ROOT="/workspace/runpod-slim/ComfyUI"
elif [ -d "/workspace/ComfyUI/models" ]; then
    COMFY_ROOT="/workspace/ComfyUI"
elif [ -d "/ComfyUI/models" ]; then
    COMFY_ROOT="/ComfyUI"
else
    echo "❌ Could not find ComfyUI models folder"
    exit 1
fi

echo "Using ComfyUI at: $COMFY_ROOT"
echo

BASE_PATH="$COMFY_ROOT/models"
mkdir -p "$BASE_PATH/diffusion_models" \
         "$BASE_PATH/vae" \
         "$BASE_PATH/text_encoders" \
         "$BASE_PATH/loras" \
         "$BASE_PATH/wildcards"

echo "Models path: $BASE_PATH"
echo

echo "=== Installing core custom nodes ==="
CUSTOM_NODE_PATH="$COMFY_ROOT/custom_nodes"
mkdir -p "$CUSTOM_NODE_PATH"
cd "$CUSTOM_NODE_PATH"

install_node () {
    REPO_URL="$1"
    NAME=$(basename "$REPO_URL" .git)

    if [ -d "$NAME" ]; then
        echo "✔ $NAME already exists, pulling latest"
        cd "$NAME"
        git pull --ff-only || true
        cd ..
    else
        echo "Cloning $NAME"
        git clone --depth 1 "$REPO_URL"
    fi
}

install_node https://github.com/GadzoinksOfficial/comfyui_gprompts.git
install_node https://github.com/rgthree/rgthree-comfy.git
install_node https://github.com/cubiq/ComfyUI_essentials.git
install_node https://github.com/Stduhpf/ComfyUI-WanMoeKSampler.git
install_node https://github.com/kijai/ComfyUI-KJNodes.git
install_node https://github.com/M1kep/ComfyLiterals.git
install_node https://github.com/ClownsharkBatwing/RES4LYF.git
install_node https://github.com/11dogzi/Comfyui-ergouzi-Nodes.git
install_node https://github.com/kijai/ComfyUI-GIMM-VFI.git
install_node https://github.com/Smirnov75/ComfyUI-mxToolkit.git
install_node https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
install_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

echo "✔ Custom nodes installed"
echo

# -------------------------
# INSTALL CUSTOM NODE REQUIREMENTS (FIXED)
# -------------------------

echo "=== Installing custom node requirements ==="

# Detect correct Python (prefer ComfyUI venv)
if [ -f "$COMFY_ROOT/.venv-cu128/bin/python" ]; then
  VENV_PYTHON="$COMFY_ROOT/.venv-cu128/bin/python"
elif [ -f "$COMFY_ROOT/.venv/bin/python" ]; then
  VENV_PYTHON="$COMFY_ROOT/.venv/bin/python"
else
  echo "⚠ No ComfyUI venv found, using system python"
  VENV_PYTHON=python3
fi

echo "Using Python: $VENV_PYTHON"

echo "Using RunPod's preinstalled PyTorch/CUDA environment"

for dir in "$CUSTOM_NODE_PATH"/*
do
    req="$dir/requirements.txt"

    if [ -f "$req" ]; then
        name=$(basename "$dir")
        echo "Installing requirements for $name"
        $VENV_PYTHON -m pip install --upgrade --no-cache-dir -r "$req" || true
    fi
done

echo "✔ Custom node requirements installed"

echo "Using ComfyUI at: $COMFY_ROOT"
echo "Models path: $BASE_PATH"

  # -------------------------
  # QWEN
  # -------------------------

  if [ "$MODE" = "image" ] || [ "$MODE" = "both" ]; then

  echo "Installing Qwen Base Model..."
  cd "$BASE_PATH/diffusion_models"
  if [ ! -f "qwen_image_fp8_e4m3fn.safetensors" ]; then
    wget -q --show-progress -O qwen_image_fp8_e4m3fn.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors \
    || echo "⚠ Qwen model download failed"
  else
    echo "✔ Qwen base model exists"
  fi

  echo "Installing Qwen VAE..."
  cd "$BASE_PATH/vae"
  if [ ! -f "qwen_image_vae.safetensors" ]; then
    wget -q --show-progress -O qwen_image_vae.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors \
    || echo "⚠ VAE download failed"
  else
    echo "✔ Qwen VAE exists"
  fi

  echo "Installing Qwen Text Encoder..."
  cd "$BASE_PATH/text_encoders"
  if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    wget -q --show-progress -O qwen_2.5_vl_7b_fp8_scaled.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    || echo "⚠ Text encoder download failed"
  else
    echo "✔ Qwen Text Encoder exists"
  fi

fi

# -------------------------
# IMAGE LORAS
# -------------------------

if [ "$MODE" = "image" ] || [ "$MODE" = "both" ]; then

  if [ -z "${civitai_token:-}" ]; then
    echo "❌ civitai_token not set"
    exit 1
  fi

  echo "=== Installing Image Mode CivitAI LoRAs ==="
  cd "$BASE_PATH/loras"

  declare -A IMAGE_LORAS=(
    [2106185]="qwen_lenovo"
    [2338807]="qwen_analog"
    [2108245]="qwen_adorable"
    [2436841]="qwen_coolshot"
    [2207719]="qwen_filmstill"
    [2270374]="qwen_samsung"
    [2233198]="qwen_SNOFS"
    [2195978]="qwen_MYSTIC"
    [2316696]="qwen_4PLAY"
    [2677908]="qwen_ig"
    [2335968]="qwen_1girl"
    [2637922]="qwen_innie"
    [2450317]="qwen_fantasy"
    [2453097]="qwen_famegrid"
    [2179410]="qwen_comic"
    [2596531]="qwen_tintin"
    [2450317]="qwen_pinup"
    [2540186]="qwen_ghibli"
    [2218514]="qwen_anime"
    [2143914]="qwen_flat"

  )

  for id in "${!IMAGE_LORAS[@]}"; do
    name="${IMAGE_LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "⚠ Failed: $name"
    else
      echo "$name exists"
    fi
  done

fi
# -------------------------
# VIDEO MODE WAN MODELS
# -------------------------

if [ "$MODE" = "video" ] || [ "$MODE" = "both" ]; then

  echo "=== Installing WAN base models ==="

  mkdir -p "$BASE_PATH/diffusion_models"
  mkdir -p "$BASE_PATH/vae"
  mkdir -p "$BASE_PATH/text_encoders"

  cd "$BASE_PATH/diffusion_models"

  wget -t 3 -T 30 -c https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors
  wget -t 3 -T 30 -c https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors

  wget -t 3 -T 30 -c https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors -P "$BASE_PATH/vae"

  wget -t 3 -T 30 -c https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors -P "$BASE_PATH/text_encoders"

  echo "✔ WAN base models installed"
fi

# -------------------------
# VIDEO MODE WAN LORAS
# -------------------------

# -------------------------
# VIDEO MODE WAN LORAS
# -------------------------

if [ "$MODE" = "video" ] || [ "$MODE" = "both" ]; then

  echo "=== Installing WAN Lightning LoRA ==="

  cd "$BASE_PATH/loras"

  FILE="lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank256_bf16.safetensors"
  URL="https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank256_bf16.safetensors"

  if [ ! -f "$FILE" ]; then
    echo "⬇ Downloading Lightning LoRA..."
    wget -t 3 -T 60 -c "$URL" -O "$FILE" || echo "⚠ Lightning LoRA download failed"
  else
    echo "✔ Lightning LoRA exists"
  fi

  echo "=== Installing WAN Video LoRAs ==="

  if [ -z "${civitai_token:-}" ]; then
    echo "❌ civitai_token not set"
    exit 1
  fi

  cd "$BASE_PATH/loras"

    declare -A LORAS=(

      [2315187]="wan_jiggle_lo"
      [2315167]="wan_jiggle_hi"

      [2073605]="wan_nsfwsks_hi"
      [2083303]="wan_nsfwsks_lo"

      [2484657]="wan_k3nk_hi"
      [2538990]="wan_k3nk_lo"

      [2370687]="wan_bbc_bj_hi"
      [2370744]="wan_bbc_bj_lo"

      [2553271]="wan_dr34ml4y_lo"
      [2553151]="wan_dr34ml4y_hi"
      
      [2209354]="wan_bounce_hi"
      [2209344]="wan_bounce_lo"
      
      [2246669]="wan_ripple_hi"
      [2246694]="wan_ripple_lo"

      [2273468]="wan_slop_hi"
      [2273467]="wan_slop_lo"

      [2235299]="wan_2xbj_hi"
      [2235288]="wan_2xbj_lo"

      [2546793]="wan_struts_hi"
      [2546797]="wan_struts_lo"

      [2195559]="wan_deep_hi"
      [2195625]="wan_deep_lo"

      [2663475]="wan_press_hi"
      [2663487]="wan_press_lo"

      [2419370]="wan_ahe_hi"
      [2419374]="wan_ahe_lo"

      [2510280]="wan_move_hi"
      [2510218]="wan_move_lo"

      [2648813]="wan_ride_hi"
      [2648814]="wan_ride_lo"

      [2508498]="wan_twk_hi"
      [2514311]="wan_twk_lo"

      [2517513]="wan_deepface_hi"
      [2517548]="wan_deepface_lo"
    )

  for id in "${!LORAS[@]}"; do
    name="${LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      echo "⬇ Downloading $name"
      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "⚠ Failed: $name"
    fi
  done

  echo "✔ WAN LoRAs ready"

fi

# -------------------------
# WORKFLOWS
# -------------------------
# Google Drive workflow sync removed.
# Put your workflow JSON files directly in this repo and copy them manually,
# or add local copy commands here later.

echo "=== BOOTSTRAP COMPLETE ==="