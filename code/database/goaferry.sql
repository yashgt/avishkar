insert into fleet(fleet_name, parent_fleet_id, gtfs_agency_id, fleet_type, avg_speed,cen_lat,cen_lon,ne_lat,ne_lon,sw_lat,sw_lon, zoom,agency_lang,agency_timezone,agency_phone,agency_url) 
values ('Goa Ferry Service', 1, 'rnd-goa-in', 4, 30, 15.359136354931396,73.922923046875, 15.623816008758071,74.57660957031248, 15.094120426436618,73.26923652343748, 10, 'en', 'Asia/Kolkata', '(0091)0832-2410801', 'http://www.rnd.goa.gov.in');

set @goaferryid = last_insert_id();
insert into user(username, password, fleet_id, role_type) values ('ferry', 'ferry123', @goaferryid, 2);
