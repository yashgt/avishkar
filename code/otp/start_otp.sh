#cd OpenTripPlanner
#java -Xmx512M -jar target/otp.jar --server -g ../pdx -p 9090 --securePort 9091 &
nohup java -Xmx512M -jar ${OTPHOME}/otp-0.20.0-20160422.165451-50-shaded.jar --basePath ${OTPHOME} --router rnd-goa-in --server &