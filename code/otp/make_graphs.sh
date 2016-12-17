mkdir -p ${OTPHOME}/graphs
OTPGRAPHDIR=${OTPHOME}/graphs

mkdir -p ${OTPGRAPHDIR}/rnd-goa-in
cp ../database/gtfs_8.zip ${OTPGRAPHDIR}/rnd-goa-in/
java -Xmx512M -jar ${OTPHOME}/otp-0.20.0-20160422.165451-50-shaded.jar --basePath ${OTPHOME} --build ${OTPGRAPHDIR}/rnd-goa-in
#mv gtfs/*.obj ${OTPHOME}/graphs/
