@echo off
setlocal
cd /d "%~dp0"
if /i not "%~1"=="run" (
  echo Amalka backend: setup and tests. This can take a few minutes...
  call "%~f0" run > "%~dp0setup-log.txt" 2>&1
  echo.
  echo Finished. Full output is in setup-log.txt
  timeout /t 20
  exit /b
)

echo ===== TOOLS =====
echo [1/8] Checking Node and Docker >con
where node || (echo NODE_MISSING & exit /b 10)
node -v
call npm -v
set HAVE_DOCKER=1
where docker || set HAVE_DOCKER=0
if "%HAVE_DOCKER%"=="1" docker version --format "{{.Server.Version}}" || set HAVE_DOCKER=0
echo HAVE_DOCKER=%HAVE_DOCKER%

echo ===== ENV =====
echo [2/8] Creating .env >con
node scripts\init-env.js || exit /b 13

echo ===== NPM INSTALL =====
echo [3/8] npm install - first run takes a few minutes >con
call npm install --no-audit --no-fund || (echo NPM_INSTALL_FAILED & exit /b 30)
call npx prisma generate
echo GENERATE_EXIT=%ERRORLEVEL%

echo ===== TYPECHECK =====
echo [4/8] Type-checking >con
call npm run typecheck
echo TYPECHECK_EXIT=%ERRORLEVEL%

echo ===== UNIT TESTS =====
echo [5/8] Unit tests >con
set SKIP_DB_SETUP=1
call npx vitest run tests/engine.unit.test.ts
echo UNIT_EXIT=%ERRORLEVEL%
set SKIP_DB_SETUP=

if "%HAVE_DOCKER%"=="0" (
  echo DOCKER_NOT_AVAILABLE - skipping database steps
  echo ALL_DONE
  exit /b 0
)

echo ===== DOCKER COMPOSE =====
echo [6/8] Starting PostgreSQL and Redis containers >con
docker compose up -d --wait || (echo COMPOSE_FAILED & exit /b 20)

echo ===== MIGRATE =====
call npx prisma migrate deploy || (echo MIGRATE_FAILED & exit /b 40)
call npx prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --exit-code
echo DIFF_EXIT=%ERRORLEVEL%

echo ===== TESTS =====
echo [7/8] Running full test suite >con
call npm test
echo TEST_EXIT=%ERRORLEVEL%

echo ===== SEED =====
echo [8/8] Seeding sample data >con
call npm run db:seed
echo SEED_EXIT=%ERRORLEVEL%
echo ALL_DONE
