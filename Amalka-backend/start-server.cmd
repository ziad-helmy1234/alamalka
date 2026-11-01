@echo off
cd /d "%~dp0"
title Amalka API - close this window to stop the server
echo Starting PostgreSQL and Redis...
docker compose up -d --wait
echo Starting API on http://localhost:4000  (docs: http://localhost:4000/api/docs)
call npm run dev
pause
