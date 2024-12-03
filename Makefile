# Variables
ENCODED_VALIDATOR="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL1ZpY3RvckdTYW5kb3ZhbC9MYWJLOFMvcmVmcy9oZWFkcy9tYWluL3N0dWRlbnRfdmFsaWRhdG9yLnNo"
VALIDATOR_SCRIPT=/tmp/student_validator.sh

# Decodificar la URL Base64
VALIDATOR_URL=$(shell echo $(ENCODED_VALIDATOR) | base64 -d)

# Tarea principal: Validar
validate:
	@echo "Instalando validador..."
	@trap "rm -f $(VALIDATOR_SCRIPT)" EXIT INT TERM HUP  # Limpieza segura
	@curl -s -o $(VALIDATOR_SCRIPT) $(VALIDATOR_URL)
	@chmod +x $(VALIDATOR_SCRIPT)
	@echo "Ejecutando validador con correo: ${STUDENT_EMAIL}"
	@STUDENT_EMAIL=${STUDENT_EMAIL} bash $(VALIDATOR_SCRIPT)

# Limpieza manual (opcional)
clean:
	rm -f $(VALIDATOR_SCRIPT)
