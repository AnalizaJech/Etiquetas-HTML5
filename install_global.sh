#!/bin/bash

# Archivos temporales para guardar el estado
STUDENT_EMAIL_FILE="/tmp/student_email.txt"
BACKEND_PORT_FILE="/tmp/backend_port.txt"
FRONTEND_PORT_FILE="/tmp/frontend_port.txt"
RBAC_FILE="rbac-config.yaml"
DEPLOYMENT_FILE="kubectl-client.yaml"

# Obtener correo del estudiante
get_student_email() {
    if [[ -f "$STUDENT_EMAIL_FILE" ]]; then
        STUDENT_EMAIL=$(cat "$STUDENT_EMAIL_FILE")
        echo "Usando correo previamente guardado: $STUDENT_EMAIL"
    else
        echo -n "Ingresa tu correo institucional (terminado en vallegrande.edu.pe): "
        read STUDENT_EMAIL
        if [[ ! "$STUDENT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@vallegrande\.edu\.pe$ ]]; then
            echo "Error: El correo debe ser válido y del dominio vallegrande.edu.pe."
            exit 1
        fi
        echo "$STUDENT_EMAIL" > "$STUDENT_EMAIL_FILE"
        echo "Correo capturado: $STUDENT_EMAIL"
    fi
}

# Obtener puertos del backend y frontend
get_ports() {
    if [[ -f "$BACKEND_PORT_FILE" && -f "$FRONTEND_PORT_FILE" ]]; then
        PUERTO_BACKEND_ENV=$(cat "$BACKEND_PORT_FILE")
        PUERTO_FRONTEND_ENV=$(cat "$FRONTEND_PORT_FILE")
        echo "Usando puertos previamente guardados: Backend=$PUERTO_BACKEND_ENV, Frontend=$PUERTO_FRONTEND_ENV"
    else
        echo -n "Ingresa el puerto del Backend (por defecto 8080): "
        read PUERTO_BACKEND_ENV
        PUERTO_BACKEND_ENV=${PUERTO_BACKEND_ENV:-8080}

        echo -n "Ingresa el puerto del Frontend (por defecto 4200): "
        read PUERTO_FRONTEND_ENV
        PUERTO_FRONTEND_ENV=${PUERTO_FRONTEND_ENV:-4200}

        echo "$PUERTO_BACKEND_ENV" > "$BACKEND_PORT_FILE"
        echo "$PUERTO_FRONTEND_ENV" > "$FRONTEND_PORT_FILE"
        echo "Puertos capturados: Backend=$PUERTO_BACKEND_ENV, Frontend=$PUERTO_FRONTEND_ENV"
    fi
}

# Actualizar los manifiestos con las variables
update_manifests() {
    # Descargar el archivo RBAC
    curl -s -o "$RBAC_FILE" "https://raw.githubusercontent.com/VictorGSandoval/LabK8S/refs/heads/main/yml/rbac-config.yaml"

    # Descargar el archivo del Deployment
    curl -s -o "$DEPLOYMENT_FILE" "https://raw.githubusercontent.com/VictorGSandoval/LabK8S/refs/heads/main/yml/kubectl-client.yaml"

    # Detectar el sistema operativo
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: usar -i '' para evitar archivos de respaldo
        sed -i '' "s/{{STUDENT_EMAIL}}/$STUDENT_EMAIL/g" "$DEPLOYMENT_FILE"
        sed -i '' "s/{{PUERTO_BACKEND_ENV}}/$PUERTO_BACKEND_ENV/g" "$DEPLOYMENT_FILE"
        sed -i '' "s/{{PUERTO_FRONTEND_ENV}}/$PUERTO_FRONTEND_ENV/g" "$DEPLOYMENT_FILE"
    else
        # Linux: usar -i sin extensión
        sed -i "s/{{STUDENT_EMAIL}}/$STUDENT_EMAIL/g" "$DEPLOYMENT_FILE"
        sed -i "s/{{PUERTO_BACKEND_ENV}}/$PUERTO_BACKEND_ENV/g" "$DEPLOYMENT_FILE"
        sed -i "s/{{PUERTO_FRONTEND_ENV}}/$PUERTO_FRONTEND_ENV/g" "$DEPLOYMENT_FILE"
    fi
}


# Aplicar los manifiestos
apply_manifests() {
    echo "Aplicando manifiestos..."
    kubectl apply -f "$RBAC_FILE"
    kubectl apply -f "$DEPLOYMENT_FILE"
    echo "Esperando a que el pod de kubectl esté listo..."
    kubectl wait --for=condition=ready pod -l app=kubectl-client -n default --timeout=60s
    pod_name=$(kubectl get pods -n default -l app=kubectl-client -o jsonpath="{.items[0].metadata.name}")
    
    if [[ -z "$pod_name" ]]; then
        echo "Error: No se encontró ningún pod con la etiqueta 'app=kubectl-client'." >&2
        exit 1
    fi
    
    #echo "Esperando a que el pod esté en estado 'Running'..."
    
    # Esperar hasta que el pod esté listo
    #kubectl wait --for=condition=ready pod/$pod_name -n default --timeout=60s
    
    echo "Mostrando logs en tiempo real del pod: $pod_name"
    
    # Seguir los logs del pod
    kubectl logs -f $pod_name -n default
}

# Destruir los recursos creados
destroy_resources() {
    echo "Eliminando recursos y pod de kubectl..."
    pod_name=$(kubectl delete -f "$DEPLOYMENT_FILE" --ignore-not-found)
    #kubectl delete -f "$RBAC_FILE" --ignore-not-found
    kubectl delete pod -l app=kubectl-client -n default --wait=true
    rm $RBAC_FILE
    rm $DEPLOYMENT_FILE
    echo "Recursos eliminados."
}

# Flujo principal
main() {
    destroy_resources
    echo "Iniciando configuración..."
    get_student_email
    get_ports
    update_manifests
    apply_manifests
    destroy_resources
}

# Permitir destrucción desde la línea de comandos
if [[ "$1" == "destroy" ]]; then
    destroy_resources
else
    main
fi
