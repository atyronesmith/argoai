#!/usr/bin/env python3
"""
AI-Enhanced Document Processing Pipeline Setup
A more robust Python implementation with error handling and logging
"""

import subprocess
import time
import json
import logging
import sys
from pathlib import Path
from typing import Dict, Optional, List
import yaml
import requests
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class OpenShiftPipelineSetup:
    """Manages the setup of AI document processing pipeline on OpenShift"""

    def __init__(self, project_name: str = "argo-ai-demo"):
        self.project_name = project_name
        self.kubeconfig = None
        self.api_client = None
        self.v1 = None
        self.apps_v1 = None

    def check_crc_status(self) -> bool:
        """Check if CRC is running"""
        try:
            result = subprocess.run(
                ["crc", "status"],
                capture_output=True,
                text=True
            )
            return "Running" in result.stdout
        except FileNotFoundError:
            logger.error("CRC not found. Please install OpenShift Local")
            return False

    def start_crc(self, cpus: int = 6, memory: int = 16384, disk: int = 60):
        """Start CRC with specified resources"""
        if self.check_crc_status():
            logger.info("CRC is already running")
            return True

        logger.info(f"Starting CRC with {cpus} CPUs, {memory}MB RAM, {disk}GB disk")
        cmd = [
            "crc", "start",
            "--cpus", str(cpus),
            "--memory", str(memory),
            "--disk-size", str(disk)
        ]

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        # Stream output
        for line in process.stdout:
            logger.info(line.strip())

        process.wait()
        return process.returncode == 0

    def get_kubeadmin_password(self) -> Optional[str]:
        """Extract kubeadmin password from CRC"""
        try:
            result = subprocess.run(
                ["crc", "console", "--credentials"],
                capture_output=True,
                text=True
            )

            for line in result.stdout.split('\n'):
                if 'kubeadmin' in line and '-p' in line:
                    parts = line.split('-p')
                    if len(parts) > 1:
                        password = parts[1].split()[0]
                        return password
        except Exception as e:
            logger.error(f"Failed to get kubeadmin password: {e}")
        return None

    def setup_kubernetes_client(self):
        """Configure Kubernetes client for OpenShift"""
        # Get CRC kubeconfig
        subprocess.run(["eval", "$(crc oc-env)"], shell=True)

        # Load config
        config.load_kube_config()

        # Create API clients
        self.api_client = client.ApiClient()
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.custom_objects = client.CustomObjectsApi()

    def create_project(self):
        """Create OpenShift project"""
        try:
            # Check if project exists
            projects = self.v1.list_namespace()
            for proj in projects.items:
                if proj.metadata.name == self.project_name:
                    logger.info(f"Project {self.project_name} already exists")
                    return

            # Create new project
            namespace = client.V1Namespace(
                metadata=client.V1ObjectMeta(name=self.project_name)
            )
            self.v1.create_namespace(namespace)
            logger.info(f"Created project {self.project_name}")

        except ApiException as e:
            logger.error(f"Failed to create project: {e}")
            raise

    def deploy_argo_workflows(self):
        """Deploy Argo Workflows"""
        logger.info("Deploying Argo Workflows...")

        # Download Argo installation
        argo_url = "https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/install.yaml"
        response = requests.get(argo_url)

        # Parse and modify namespace
        documents = yaml.safe_load_all(response.text)

        for doc in documents:
            if doc and 'metadata' in doc:
                if 'namespace' in doc['metadata']:
                    doc['metadata']['namespace'] = self.project_name

                # Apply the resource
                self._apply_resource(doc)

    def deploy_ollama(self, model: str = "llama3.2:3b"):
        """Deploy Ollama with specified model"""
        logger.info("Deploying Ollama service...")

        # Create PVC
        pvc = client.V1PersistentVolumeClaim(
            metadata=client.V1ObjectMeta(
                name="ollama-models-pvc",
                namespace=self.project_name
            ),
            spec=client.V1PersistentVolumeClaimSpec(
                access_modes=["ReadWriteOnce"],
                resources=client.V1ResourceRequirements(
                    requests={"storage": "20Gi"}
                )
            )
        )

        try:
            self.v1.create_namespaced_persistent_volume_claim(
                namespace=self.project_name,
                body=pvc
            )
        except ApiException as e:
            if e.status != 409:  # Ignore if already exists
                raise

        # Create Deployment
        deployment = client.V1Deployment(
            metadata=client.V1ObjectMeta(
                name="ollama",
                namespace=self.project_name
            ),
            spec=client.V1DeploymentSpec(
                replicas=1,
                selector=client.V1LabelSelector(
                    match_labels={"app": "ollama"}
                ),
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={"app": "ollama"}
                    ),
                    spec=client.V1PodSpec(
                        containers=[
                            client.V1Container(
                                name="ollama",
                                image="docker.io/ollama/ollama:latest",
                                ports=[
                                    client.V1ContainerPort(container_port=11434)
                                ],
                                env=[
                                    client.V1EnvVar(
                                        name="OLLAMA_HOST",
                                        value="0.0.0.0"
                                    )
                                ],
                                resources=client.V1ResourceRequirements(
                                    requests={
                                        "memory": "4Gi",
                                        "cpu": "2"
                                    },
                                    limits={
                                        "memory": "8Gi",
                                        "cpu": "4"
                                    }
                                ),
                                volume_mounts=[
                                    client.V1VolumeMount(
                                        name="ollama-models",
                                        mount_path="/models"
                                    )
                                ]
                            )
                        ],
                        volumes=[
                            client.V1Volume(
                                name="ollama-models",
                                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                                    claim_name="ollama-models-pvc"
                                )
                            )
                        ]
                    )
                )
            )
        )

        try:
            self.apps_v1.create_namespaced_deployment(
                namespace=self.project_name,
                body=deployment
            )
            logger.info("Ollama deployment created")
        except ApiException as e:
            if e.status != 409:
                raise

        # Wait for deployment
        self._wait_for_deployment("ollama")

        # Load model
        self._load_ollama_model(model)

    def _apply_resource(self, manifest: dict):
        """Apply a Kubernetes resource from manifest"""
        try:
            kind = manifest.get('kind')
            api_version = manifest.get('apiVersion')

            if not kind or not api_version:
                return

            # Route to appropriate API based on kind
            if kind == "Deployment":
                self.apps_v1.create_namespaced_deployment(
                    namespace=self.project_name,
                    body=manifest
                )
            elif kind == "Service":
                self.v1.create_namespaced_service(
                    namespace=self.project_name,
                    body=manifest
                )
            elif kind == "ConfigMap":
                self.v1.create_namespaced_config_map(
                    namespace=self.project_name,
                    body=manifest
                )
            # Add more resource types as needed

        except ApiException as e:
            if e.status != 409:  # Ignore already exists
                logger.warning(f"Failed to create {kind}: {e}")

    def _wait_for_deployment(self, name: str, timeout: int = 300):
        """Wait for deployment to be ready"""
        logger.info(f"Waiting for {name} deployment to be ready...")

        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                deployment = self.apps_v1.read_namespaced_deployment(
                    name=name,
                    namespace=self.project_name
                )

                if deployment.status.ready_replicas == deployment.spec.replicas:
                    logger.info(f"{name} is ready")
                    return

            except ApiException:
                pass

            time.sleep(5)

        raise TimeoutError(f"Deployment {name} not ready after {timeout} seconds")

    def _load_ollama_model(self, model: str):
        """Load model into Ollama"""
        logger.info(f"Loading model {model} into Ollama...")

        # Get Ollama pod
        pods = self.v1.list_namespaced_pod(
            namespace=self.project_name,
            label_selector="app=ollama"
        )

        if not pods.items:
            raise RuntimeError("Ollama pod not found")

        pod_name = pods.items[0].metadata.name

        # Execute model pull command
        exec_command = [
            "ollama", "pull", model
        ]

        stream = client.stream.stream(
            self.v1.connect_get_namespaced_pod_exec,
            pod_name,
            self.project_name,
            command=exec_command,
            stderr=True,
            stdin=False,
            stdout=True,
            tty=False
        )

        logger.info(f"Model {model} loaded successfully")


def main():
    """Main setup function"""
    setup = OpenShiftPipelineSetup()

    try:
        # Start CRC
        if not setup.start_crc():
            logger.error("Failed to start CRC")
            sys.exit(1)

        # Setup Kubernetes client
        setup.setup_kubernetes_client()

        # Create project
        setup.create_project()

        # Deploy components
        setup.deploy_argo_workflows()
        setup.deploy_ollama()

        logger.info("Setup completed successfully!")

    except Exception as e:
        logger.error(f"Setup failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
