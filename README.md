Student 1: Eyad Elhati #20221050
Student 2: Mohammad Tamer Dukmak #20221038
Student 3: Yaser Karamohammed #20221180


# Book Shop - Docker Deployment

## What this is
A Django book shop app containerized using Docker, PostgreSQL, and Nginx.

## Requirements
- Docker
- Docker Compose

## Setup

1. Clone the repo
   git clone https://github.com/EyadElhatty/book-shop
   cd book-shop

2. Create your .env file from the template
   cp .env.example .env
   Then open .env and fill in your values

3. Run the app
   docker-compose up --build

4. Open your browser
   http://localhost

## Pages
- http://localhost — homepage
- http://localhost/book-list — list of all books
- http://localhost/book-detail/1/ — book detail page
- http://localhost/admin — admin panel

## Services
- db: PostgreSQL 15 database
- backend: Django app served by gunicorn
- nginx: reverse proxy listening on port 80

## How it works
- Nginx receives all requests on port 80
- Static files are served directly by Nginx
- All other requests are forwarded to Django
- Django connects to PostgreSQL for data

## To stop
   docker-compose down

# Phase 2 CI/CD Testing
