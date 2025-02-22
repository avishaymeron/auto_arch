SHELL := /bin/bash  # Specify bash as the shell

.PHONY: install run-backend run-frontend run-all

install:
	# Install frontend dependencies
	cd frontend && npm install
	# Install backend dependencies
	. venv/bin/activate && pip install -r backend/requirements.txt

run-backend:
	. venv/bin/activate && cd backend && uvicorn app.main:app --reload --port 8000

run-frontend:
	cd frontend && npm start

run-all:
	@echo "Starting all services..."
	@gnome-terminal --tab --title="Backend" -- bash -c "make run-backend"
	@gnome-terminal --tab --title="Frontend" -- bash -c "make run-frontend"
