# 📜 Jais AI Utility Scripts

Essential utility scripts for the Jais AI project.

## Available Scripts

### `model_download.sh`
Downloads the Jais AI 30B 16K Chat GGUF model from Hugging Face.

```bash
./scripts/model_download.sh
```

**Features:**
- Downloads ~26GB GGUF model file
- Verifies download integrity  
- Creates models directory if needed
- Works with both Docker and native execution

## Usage Notes

- Run scripts from the project root directory
- Model will be downloaded to `./models/` directory  
- Ensure sufficient disk space (30GB+ recommended)

---

💡 **For main project usage, see [../README.md](../README.md)**

- **Automatic Use (Recommended):**
  - The script is called automatically during Docker container build or startup (via entrypoint or startup scripts).
  - It ensures the model is present before the server starts, so deployments are always ready.
  - If a valid model file already exists in `/app/models`, the script will:
    - Print the model’s size and SHA256 hash.
    - In non-interactive (automated) runs, it will skip the download and use the existing model.
    - In interactive runs, it will prompt the user to confirm overwriting the file.

- **Manual Use:**
  - You can run the script manually inside a running container (e.g., with `docker exec`) to re-download or update the model.

- **Not for Local Use:**
  - The script is intended for use inside the Docker container only, not for local development outside Docker.

**Summary:**
- The script is safe and efficient: it will not overwrite a valid model file unless you explicitly confirm in an interactive shell.
- In automated Docker runs, it will always use the existing model if present, ensuring fast and reliable container startup.
