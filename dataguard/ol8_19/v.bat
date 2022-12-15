@echo on

if "a%1%"=="a" (
  echo No parameter given
  exit /b
)

if %1%==up (
  cd node1
  vagrant up
  cd ..
  cd node2
  vagrant up
  cd ..
)

if %1%==halt (
  cd node2
  vagrant halt
  cd ..
  cd node1
  vagrant halt
  cd ..
)

if %1%==destroy (
  cd node2
  vagrant destroy 
  cd ..
  cd node1
  vagrant destroy
  cd ..
)

if %1%==status (
  cd node1
  vagrant status
  cd ..
  cd node2
  vagrant status
  cd ..
)


pause
