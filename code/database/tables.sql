CREATE DATABASE if not exists avishkar;

USE avishkar;

CREATE TABLE if not exists fleetgroup
(
fleetgroup_name varchar(255),
fleetgroup_id int,
username varchar(255),
password varchar(255),
PRIMARY KEY (fleetgroup_id)
);

CREATE TABLE if not exists fleet
(
fleet_name varchar(255) comment 'Agency name to be used in GTFS',
fleet_id int auto_increment,
parent_fleet_id int,
fleetgroup_id int,
gtfs_agency_id varchar(255) comment 'Agency ID to be used in generated GTFS',
fleet_type int comment '3=Bus',
avg_speed int comment 'Average speed of a bus in the fleet',
cen_lat float,
cen_lon float,
ne_lat float,
ne_lon float,
sw_lat float,
sw_lon float,
zoom int,
agency_lang varchar (5),
agency_timezone varchar (20),
agency_phone varchar (20),
agency_url varchar (255),
PRIMARY KEY (fleet_id),
FOREIGN KEY (fleetgroup_id) REFERENCES fleetgroup(fleetgroup_id),
FOREIGN KEY (parent_fleet_id) REFERENCES fleet(fleet_id)
) 
comment 'Every Agency is listed here'
;

CREATE TABLE if not exists user
(
username varchar(255),
password varchar(255),
user_id int AUTO_INCREMENT,
fleet_id int,
role_type int comment '1=Admin, 2=Super Admin',
PRIMARY KEY (user_id),
FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id)
);

CREATE TABLE if not exists session
(
date DATE,
time TIME,
session_id int AUTO_INCREMENT,
user_id int,
PRIMARY KEY (session_id),
FOREIGN KEY (user_id) REFERENCES user(user_id)
);

CREATE TABLE if not exists stop
(
stop_id int AUTO_INCREMENT,
fleet_id int comment 'Fleet to which the stop belongs. This is always the Root Fleet',
code varchar(255) comment 'Internal code of the stop',
location_status int default 2 comment 'Bitmap for 0: Random, 1:Geocoded, 2:Located by Google Places, 4:Located correctly, 8:Google location rectified',
latitude decimal(25,20),
longitude decimal(25,20),
name varchar(255),
is_station boolean DEFAULT 0,
alias_name1 varchar(255),
alias_name2 varchar(255),
locality varchar(500),
stop_loc_id int,
peer_stop_id int,
user_id int,
g_place_id varchar(255) comment 'ID of the place indexed by Google',
g_place_name varchar(255) comment 'Name of the place given by Google'
,PRIMARY KEY (stop_id)
,FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id)
,FOREIGN KEY (peer_stop_id) REFERENCES stop(stop_id)
,foreign key (user_id) references user(user_id)
);


CREATE TABLE if not exists stop_loc
(
stop_id int,
location point not null,
loc_text varchar(255),
FOREIGN KEY (stop_id) REFERENCES stop(stop_id)
,SPATIAL INDEX(location)
) ENGINE = MyISAM;

CREATE TABLE if not exists route
(
route_id INT AUTO_INCREMENT,
gtfs_route_id int,
fleet_id int comment 'Fleet to which the route belongs. This is always the Root Fleet',
is_deleted boolean DEFAULT 0,
route_name varchar(255),
start_stop_id int,
end_stop_id int,
PRIMARY KEY (route_id),
FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id),
foreign key (start_stop_id) references stop(stop_id),
foreign key (end_stop_id) references stop(stop_id)
);



delimiter //
drop trigger if exists ins_stop//
CREATE TRIGGER ins_stop AFTER INSERT ON stop
for each row 
begin
	declare p varchar(255);
	set p=concat('POINT(', CAST(NEW.latitude as CHAR),' ',CAST(NEW.longitude as CHAR),')') ; 
	
	insert into stop_loc(
	stop_id
	, location
	, loc_text
	) 
	values(
	NEW.stop_id
	, PointFromText(p)
	, p
	);
end;//
delimiter ;

create or replace view stop_detail
as
select S.stop_id, latitude, longitude, name, location
from stop S
inner join stop_loc L on (S.stop_id=L.stop_id);


CREATE TABLE if not exists stage
(
stage_id int AUTO_INCREMENT,
stage_name varchar(255),
route_id int,
PRIMARY KEY (stage_id),
FOREIGN KEY (route_id) REFERENCES route(route_id)
);

CREATE TABLE if not exists routestop
(
stop_id int,
peer_stop_id int comment 'Stop in the reverse direction. This is nulable',
route_id int,
stage_id int,
sequence int,
route_stop_id int AUTO_INCREMENT,
PRIMARY KEY (route_stop_id),
FOREIGN KEY (route_id) REFERENCES route(route_id),
FOREIGN KEY (stage_id) REFERENCES stage(stage_id),
FOREIGN KEY (stop_id) REFERENCES stop(stop_id)
);


CREATE TABLE if not exists trip 
(
trip_id int AUTO_INCREMENT,
trip_name varchar(255) comment 'trip_id in GTFS',
fleet_id int not null,
calendar_id int not null comment 'Calendar followed by this trip',
direction boolean,
route_id int not null,
frequency_trip boolean default false comment 'True if this entry represents multiple trips spread at a given frequency',
frequency_start_time time comment 'Time at which the trips operate on a frequency',
frequency_end_time time,
frequency_gap time comment 'Time difference between 2 trips of this frequency trip',
last_upd_by int,
last_upd_on datetime, 
PRIMARY KEY (trip_id),
FOREIGN KEY (route_id) REFERENCES route(route_id),
FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id),
FOREIGN KEY (last_upd_by) REFERENCES user(user_id)
) comment 'Used for trips.txt and frequencies.txt';

CREATE TABLE if not exists trip_history
(
trip_id int ,
trip_name varchar(255),
fleet_id int,
direction boolean,
frequency_trip boolean,
frequency_start_time time,
frequency_end_time time,
last_upd_by int,
last_upd_on datetime,
FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id)
);

CREATE TABLE if not exists routestoptrip
(
route_stop_id int,
trip_id int,
time time,
FOREIGN KEY (route_stop_id) REFERENCES routestop(route_stop_id) on delete cascade,
FOREIGN KEY (trip_id) REFERENCES trip(trip_id) on delete cascade,
CONSTRAINT pk_rst PRIMARY KEY (route_stop_id,trip_id)  
);

create table if not exists numbers
(
	num int,
	primary key (num)
);

delimiter //
drop procedure if exists populate_numbers//
CREATE PROCEDURE populate_numbers(maxval INT)
BEGIN

DECLARE v1 INT DEFAULT 1;
WHILE v1 <= maxval DO
	insert into numbers(num) values (v1);
    SET v1 = v1 + 1;
END WHILE;
END//
delimiter ;

delete from numbers;
CALL populate_numbers(1000);

create or replace view vw_stop_trips
as
select
	T.trip_id as trip_id
	, RS.stop_id as stop_id
	, case T.frequency_trip 
		when 1 then addtime(RST.time, sec_to_time(N.num*time_to_sec(T.frequency_gap)))
		else RST.time 
	end as time
from 
	route as R
	inner join trip as T on (R.route_id = T.route_id)
	inner join routestop as RS on (R.route_id=RS.route_id)
	inner join routestoptrip as RST on (RS.route_stop_id=RST.route_stop_id)	
	left outer join numbers as N on 
		(T.frequency_trip=1 and time_to_sec(timediff(T.frequency_end_time, T.frequency_start_time) )  / time_to_sec(T.frequency_gap) + 1 )
	;
	

CREATE TABLE if not exists segment
(
from_stop_id int,
to_stop_id int,
distance float comment 'Distance in meters or feet',
time int,
is_stale boolean default 0,
FOREIGN KEY (from_stop_id) REFERENCES stop(stop_id),
FOREIGN KEY (to_stop_id) REFERENCES stop(stop_id)
);



CREATE TABLE if not exists calendar 
(
	calendar_id int AUTO_INCREMENT,
	fleet_id int,
	calendar_name varchar(25),
	start_date date,
	end_date date,
	mon boolean, tue boolean, wed boolean, thu boolean, fri boolean, sat boolean, sun boolean,
	PRIMARY KEY (calendar_id)
) comment 'Calendar followed by trips';

CREATE TABLE if not exists calendar_exceptions 
(
	fleet_id int,
	calendar_id int,
	exception_date date,
	include_exclude boolean
);

create table if not exists error_trips( trip_no varchar(25), depot_cd varchar(255), error varchar(500), index idx_trip_no(trip_no));



