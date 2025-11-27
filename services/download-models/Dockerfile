# Use the official Python image as a base
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Install production dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the source code into the container
COPY . .

# Set the PORT environment variable (Cloud Run will provide this, but it's good practice)
ENV PORT 8080

# The command to run the application using Gunicorn
# main:app refers to the Flask app instance named 'app' in 'main.py'
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 60 main:app