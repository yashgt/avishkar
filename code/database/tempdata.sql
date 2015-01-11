use avishkar;

insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed,cen_lat,cen_lon,ne_lat,ne_lon,sw_lat,sw_lon, zoom) 
values( 'No Fleet', null, 3, 30, 52.2681573737682,16.875, 78.56048828398782,-177.890625, -8.754794702435605,-148.359375,2);
insert into user(username, password, fleet_id, role_type) values ('yash', 'yash123', 1, 2);


insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed,cen_lat,cen_lon,ne_lat,ne_lon,sw_lat,sw_lon, zoom) 
values ('Goa Transport', 1, 3, 30, 15.359136354931396,73.922923046875, 15.623816008758071,74.57660957031248, 15.094120426436618,73.26923652343748, 10);
insert into user(username, password, fleet_id, role_type) values ('sghate', 'sghate123', 2, 2);

set @goatransid = last_insert_id();
insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed) values ('KTCL', @goatransid, 3, 30);
set @ktcltransid = last_insert_id();
insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed) values ('KTCL Shuttles', @ktcltransid, 3, 30);
insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed) values ('KTCL interstate', @ktcltransid, 3, 30);
insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed) values ('Private Buses', @goatransid, 3, 30);

insert into fleet(fleet_name, parent_fleet_id, fleet_type, avg_speed,cen_lat,cen_lon,ne_lat,ne_lon,sw_lat,sw_lon, zoom) 
values ('MH Transport', 1, 3, 30, 19.131336917005157,77.13573737792969, 21.193809145754596,82.29931159667967, 17.04278759928605,71.97216315917967,7);

select * from fleet;
call list_user_fleets(1);