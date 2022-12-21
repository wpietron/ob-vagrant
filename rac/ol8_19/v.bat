@echo on

if "a%1%"=="a" (
  echo No parameter given
  exit /b
)

if %1%==up (
  time /t
  cd dns
  vagrant up
  cd ..
  cd node2
  vagrant up
  cd ..
  cd node1
  vagrant up
  cd ..
  time /t
)

if %1%==halt (
  cd node2
  vagrant halt
  cd ..
  cd node1
  vagrant halt
  cd ..
  cd dns
  vagrant halt
  cd ..
)

if %1%==destroy (
  cd node2
  vagrant destroy -f
  cd ..
  cd node1
  vagrant destroy -f
  cd ..
  cd dns
  vagrant destroy -f
  cd ..
)

if %1%==status (
  cd node2
  vagrant status
  cd ..
  cd node1
  vagrant status
  cd ..
  cd dns
  vagrant status
  cd ..
)

pause
