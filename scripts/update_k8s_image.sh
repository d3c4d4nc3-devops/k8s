#!/bin/bash
set -euo pipefail
IMAGE_NAME="${1:-}"
K8S_DEPLOYMENT_FILE="k8s/deployment.yml"

if [[ -z "$IMAGE_NAME" ]]; then
  echo "Usage: ./scripts/update_k8s_image.sh <image:tag>"
  exit 1
fi

git config --global user.name 'GitHub Actions'
git config --global user.email 'actions@github.com'

# Обновляем строку image: ... строго по ключу container.name
# Если у тебя в deployment.yml контейнер называется иначе — замени my-app-container на своё имя
if grep -q "name: my-app-container" "$K8S_DEPLOYMENT_FILE"; then
  # Меняем только следующую строку image: после имени контейнера
  awk -v img="$IMAGE_NAME" '
    BEGIN{change=0}
    /name:[[:space:]]*my-app-container/ {print; getline; if ($0 ~ /image:/) {print "        image: " img; change=1; next}}
    {print}
    END{ if (change==0) { print "ERROR: container name not found or image line missing" > "/dev/stderr"; exit 1 } }
  ' "$K8S_DEPLOYMENT_FILE" > "${K8S_DEPLOYMENT_FILE}.tmp" && mv "${K8S_DEPLOYMENT_FILE}.tmp" "$K8S_DEPLOYMENT_FILE"
else
  # Фолбэк — грубо заменить первую попавшуюся строку image:
  sed -i "0,/image:/s|image:.*|image: ${IMAGE_NAME}|" ${K8S_DEPLOYMENT_FILE}
fi

git add ${K8S_DEPLOYMENT_FILE}
if git diff --staged --quiet; then
  echo "No changes to commit."
else
  git commit -m "Update Kubernetes image to ${IMAGE_NAME}"
fi
