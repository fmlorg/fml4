#! /bin/sh
#
# $Header: newlog.sh 0.20 95/05/08 Copyr 1995 F.Murayama


MAX=4
progname=`echo $0 | sed 's;^[^ ]*/;;'`

if [ $# -lt 2 ]; then
  echo "Usage: $progname filenames... dest-directory" 1>&2
  exit 0
fi

for i
do
   dir="$i"
done

if [ ! -d $dir ]; then
  mkdir -p $dir
  chmod 700 $dir
fi

for bak
do
  if [ $# -lt 2 ]; then
    exit 0
  fi

  new=`expr "$bak" : '\(.*\)\.bak'`
  if [ "$new" ]; then
    :
  else
    new=$bak
  fi

  if [ -f $bak -a ! -h $bak ]; then
    mv -f $bak $dir/$new.0
  fi

  max=$MAX
  if [ -f $dir/$new.$max ]; then
    rm -f $dir/$new.$max
  fi
  while [ $max -gt 0 ]
  do
    min=`expr $max - 1`
    if [ -f $dir/$new.$min ]; then
      mv -f $dir/$new.$min $dir/$new.$max
    fi
    max=$min
  done

  touch $dir/$new.0
  if [ ! -h $bak ]; then
    rm -f $bak
    ln -s $dir/$new.0 $bak 2> /dev/null
  fi
  shift
done

exit 1
