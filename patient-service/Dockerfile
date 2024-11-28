# Base image
FROM node:16-alpine

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy the application code
COPY . .

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["node", "index.js"]
