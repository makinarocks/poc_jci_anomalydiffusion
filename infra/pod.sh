#!/bin/bash
set -x
source ~/.kube/exp_vars.sh

if kubectl get pvc $RUNNER_RESOURCE_NAME-exp-pvc &>/dev/null; then
    echo "PVC already exists. Skipping PVC creation."
else
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $RUNNER_RESOURCE_NAME-exp-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: ${PVC_STORAGE_SIZE}Gi
  storageClassName: ceph-filesystem
EOF
fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $RUNNER_RESOURCE_NAME-exp-pod
  labels:
    app.makinarocks.ai/project-code: $PROJECT_CODE
    app.makinarocks.ai/user-id: $USER_NAME
spec:
  nodeName: $POD_NODE_NAME
  containers:
    - name: jci-container
      image: pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel
      env:
        - name: MLFLOW_S3_ENDPOINT_URL
          value: http://minio.fde.mrxrunway.ai
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow.fde.mrxrunway.ai/runway-project-7bfd"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: hkt-mlflow-secret
              key: MINIO_ROOT_USER
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: hkt-mlflow-secret
              key: MINIO_ROOT_PASSWORD
        - name: MLFLOW_TRACKING_USERNAME
          valueFrom:
            secretKeyRef:
              name: hkt-mlflow-secret
              key: MLFLOW_TRACKING_USERNAME
        - name: MLFLOW_TRACKING_PASSWORD
          valueFrom:
            secretKeyRef:
              name: hkt-mlflow-secret
              key: MLFLOW_TRACKING_PASSWORD
      resources:
        limits:
          memory: ${POD_LIMITS_MEMORY}Gi
          nvidia.com/gpu: $POD_REQUESTS_GPU
        requests:
          cpu: $POD_REQUESTS_CPU
          memory: ${POD_REQUESTS_MEMORY}Gi
          nvidia.com/gpu: $POD_REQUESTS_GPU
      volumeMounts:
        - name: data-volume
          mountPath: /workspace
        - mountPath: /dev/shm
          name: dshm
      command: ["/bin/bash", "-c"]
      args:
        - |
          apt update && apt install -y git && \
          if [ -d /workspace/anomalydiffusion ]; then
            echo "Removing existing anomalydiffusion directory..."
            rm -rf /workspace/anomalydiffusion
          fi && \
          echo "Activating conda and setting up environment..."
          git clone https://github.com/makinarocks/poc_jci_anomalydiffusion.git && cd /workspace/poc_jci_anomalydiffusion && \
          echo "Done. Keeping container alive..." && \
          tail -f /dev/null
  volumes:
    - name: ssh-key-volume
      secret:
        secretName: hkt-ssh-key-secret
        defaultMode: 256
    - name: data-volume
      persistentVolumeClaim:
        claimName: $RUNNER_RESOURCE_NAME-exp-pvc
    - name: dshm
      emptyDir:
        medium: Memory
        sizeLimit: 16Gi
  restartPolicy: Never
EOF

rm ~/.kube/exp_vars.sh
