FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

# Copy app code AND the bin scripts
COPY src ./src
COPY bin ./bin

# Ensure bin scripts are executable
RUN chmod +x ./bin/*

EXPOSE 3000
ENV PORT=3000

CMD ["npm", "start"]




# FROM node:20-alpine

# WORKDIR /app

# COPY package.json package-lock.json* ./
# RUN npm install --omit=dev

# COPY src ./src
# COPY bin ./bin


# EXPOSE 3000
# ENV PORT=3000
# CMD ["npm", "start"]