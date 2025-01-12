sdir=`dirname $0`
echo $sdir
cd $sdir
echo on

fleet_id=$1
skip_errors=$2
echo ${fleet_id}
folder=gtfs_${fleet_id}
mkdir -p ${folder}

#export mypath="C:\Program Files\MySQL\MySQL Server 5.6\bin"
host=`jq -r ".database.host" ../config.json`
echo $host
user=`jq -r ".database.user" ../config.json`
password=`jq -r ".database.password" ../config.json`
database=`jq -r ".database.database" ../config.json`
echo ${database}

myopts="--user=${user} --password=${password} --database=${database} --host=${host}"
echo $myopts
date
if [ ${fleet_id} -eq 7 ] 
then

mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source agency.sql;" | tr '\t' ',' > ${folder}/agency.txt
mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source calendar.sql;" | tr '\t' ',' > ${folder}/calendar.txt

myopts="--user=${user} --password=${password} --database=msrtc1 --host=${host}"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source tm_route.sql;" | tr '\t' ',' > ${folder}/routes.txt
mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source tm_stop.sql;" | tr '\t' ',' > ${folder}/stops.txt
mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source tm_trip.sql;" | tr '\t' ',' > ${folder}/trips.txt
mysql ${myopts} -e"set @fleet_id=${fleet_id}; set @skip_errors=${skip_errors}; source tm_stop_times.sql;" | tr '\t' ',' > ${folder}/stop_times.txt

else
echo "Agency"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source agency.sql;" | tr '\t' ',' > ${folder}/agency.txt
echo "Calendar"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source calendar.sql;" | tr '\t' ',' > ${folder}/calendar.txt
echo "Routes"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source route.sql;" | tr '\t' ',' > ${folder}/routes.txt
echo "Stops"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source stop.sql;" | tr '\t' ',' > ${folder}/stops.txt
echo "Trips"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source trip.sql;" | tr '\t' ',' > ${folder}/trips.txt
echo "Frequencies"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source frequencies.sql;" | tr '\t' ',' > ${folder}/frequencies.txt
echo "Times"
mysql ${myopts} -e"set @fleet_id=${fleet_id}; source stop_times.sql;" | tr '\t' ',' > ${folder}/stop_times.txt
fi
cp feed_info.txt ${folder}/feed_info.txt
date
#find ${folder} -name *.txt -empty -type f -delete
wc -l ${folder}/*.txt | sed -n 's/^[[:space:]]*0 \(.*\)/\1/p' | xargs rm

mkdir -p basepath/graphs/${folder}
zip -j -r basepath/graphs/${folder}/${folder}.zip ${folder}/*.txt
cp basepath/graphs/${folder}/${folder}.zip ${folder}.zip
#unzip -v ${folder}.zip

feedvalidator.py -l 10000 -o ../admin/public/gtfs_validation_results_${fleet_id}.html basepath/graphs/${folder}/${folder}.zip
#python /e/Projects/transitfeed/feedvalidator.py -l 10000 -o ../admin/public/gtfs_validation_results_7.html gtfs_7.zip

