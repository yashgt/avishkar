delimiter //

/* GRANT SYSTEM_VARIABLES_ADMIN ON *.* TO 'root'@'%'// */

SET GLOBAL log_bin_trust_function_creators = 1//

drop function if exists SPLIT_STR //
CREATE FUNCTION SPLIT_STR(
  x VARCHAR(255),
  delim VARCHAR(12),
  pos INT
)
RETURNS VARCHAR(255)
RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
       LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
       delim, '');
//       
       

drop procedure if exists get_location//
create procedure get_location(
	IN stop_name varchar(200)
	)
begin
	select latitude,longitude 
	from stop 
	where stop.name like stop_name ;
end//


drop function if exists hierarchy_connect_by_parent_eq_prior_id //
CREATE FUNCTION hierarchy_connect_by_parent_eq_prior_id(value INT) RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
        DECLARE _id INT;
        DECLARE _parent INT;
        DECLARE _next INT;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET @id = NULL;

        SET _parent = @id;
        SET _id = -1;

        IF @id IS NULL THEN
                RETURN NULL;
        END IF;

        LOOP
                SELECT  MIN(fleet_id)
                INTO    @id
                FROM    fleet
                WHERE   parent_fleet_id = _parent
                        AND fleet_id > _id;
                IF @id IS NOT NULL OR _parent = @start_with THEN
                        SET @level = @level + 1;
                        RETURN @id;
                END IF;
                SET @level := @level - 1;
                SELECT  fleet_id, parent_fleet_id
                INTO    _id, _parent
                FROM    fleet
                WHERE   fleet_id = _parent;
        END LOOP;       
END//

drop procedure if exists list_user_fleets//
create procedure list_user_fleets(in in_user_id int)
begin
declare user_fleet_id int;
select fleet_id into user_fleet_id from user where user_id=in_user_id;

SELECT  fleet_id as fleet_id, fleet_name, parent_fleet_id as parent_fleet_id, 0 as level
from fleet where fleet_id=user_fleet_id
union all
SELECT  hi.fleet_id as fleet_id, hi.fleet_name as fleet_name, hi.parent_fleet_id as parent_fleet_id, level
FROM    (
        SELECT  hierarchy_connect_by_parent_eq_prior_id(fleet_id) AS fleet_id, @level AS level
        FROM    (
                SELECT  @start_with := user_fleet_id, 
                        @id := @start_with ,
                        @level := 0
                ) vars	, fleet
        WHERE   @id IS NOT NULL
        ) ho
JOIN    fleet hi
ON      hi.fleet_id = ho.fleet_id;
end//

call list_user_fleets(1);

drop function if exists get_root_fleet //
create function get_root_fleet(in_fleet_id INT) RETURNS INT
begin
	DECLARE par_fleet_id INT;
	DECLARE cur_fleet_id INT;
	SET cur_fleet_id := in_fleet_id;
	SET par_fleet_id := in_fleet_id;
	
	LOOP
		select parent_fleet_id, fleet_id into par_fleet_id, cur_fleet_id
		from fleet
		where fleet_id=cur_fleet_id
		and parent_fleet_id<>1;
		
		if par_fleet_id = cur_fleet_id then
			return par_fleet_id;
		end if;
		set cur_fleet_id := par_fleet_id ;
	END LOOP;
	
end//
select get_root_fleet(3);
select get_root_fleet(4);
select get_root_fleet(2);
select get_root_fleet(1);

drop procedure if exists save_stop//
create procedure save_stop(
	INOUT id int
	, IN stop_name varchar(200)
    , IN in_internal_stop_cd varchar(200)
	, IN lat decimal(25,20)
	, IN lon decimal(25,20)
	, IN in_fleet_id int
	, IN in_peer_stop_id int
	, IN in_user_id int
)
begin
	declare root_fleet_id int;
	select get_root_fleet(in_fleet_id) into root_fleet_id;
	
	if id > 0 then /*Existing stop is being modified*/
		update stop
		set latitude=lat, longitude=lon, name=stop_name, user_id=in_user_id,location_status=4
		where stop_id=id;

		update segment 
		set is_stale=1
		where to_stop_id=id or from_stop_id=id;
	elseif(in_internal_stop_cd is not null
		and in_internal_stop_cd<>''
		and exists (select 1 from stop where code=in_internal_stop_cd and fleet_id=root_fleet_id)) then
		update stop
		set latitude=lat, longitude=lon, name=stop_name, user_id=in_user_id, location_status=4
		where code=in_internal_stop_cd and fleet_id=root_fleet_id;
	else /*New or peer stop is being created*/
		insert into stop(fleet_id, latitude, longitude, name, code, peer_stop_id, user_id) 
		values ( root_fleet_id, lat, lon, stop_name, in_internal_stop_cd, in_peer_stop_id, in_user_id) ;
		set id = LAST_INSERT_ID() ;
	
		if in_peer_stop_id > 0 then
			update stop
			set peer_stop_id=id
			where stop_id=in_peer_stop_id;		
	
		end if;
	end if;
end//

drop procedure if exists delete_stop//
create procedure delete_stop(
	IN id int,
	IN user_id int
)
begin
	delete from stop where stop_id = id;	
end//

drop procedure if exists delete_route//
create procedure delete_route(
	IN in_route_id int
)
begin
	delete from internal_route_map where route_id = in_route_id;
	delete from trip where route_id = in_route_id;
	delete from routestop where route_id = in_route_id;
	delete from stage where route_id=in_route_id;
	delete from route where route_id=in_route_id;
end//

drop procedure if exists delete_trips_for_route//
create procedure delete_trips_for_route(
	IN in_route_id int
)
begin
    delete RST
    from routestoptrip RST
    inner join trip T on (RST.trip_id=T.trip_id)
    where T.route_id = in_route_id;

	delete T
    from trip T
    where T.route_id = in_route_id;
	
	
end//


drop procedure if exists csvtodb//
create procedure csvtodb(
	  IN stop_id int
	, IN lat float
	, IN lon float
	, IN stop_name varchar(200)
)
begin
		insert into stop(stop_id, latitude, longitude, name) 
		values ( stop_id, lat, lon, stop_name) ;
end//

drop procedure if exists get_time_report//
create procedure get_time_report(in in_fleet_id int, in depot varchar(200))
begin
	declare root_fleet_id int;
	select get_root_fleet(in_fleet_id) into root_fleet_id;
	select 
	R.route_id as route_id
	, convert(R.route_id, char(10)) as route_name
    , (select group_concat(internal_route_cd separator ',') from internal_route_map group by route_id having route_id=R.route_id) as internal_route_cd
	, coalesce(S1.name
                , (select SG.stage_name 
                from stage SG 
                where SG.route_id=R.route_id 
                and SG.stage_id=(select min(SG1.stage_id) from stage SG1 where SG1.route_id=R.route_id group by SG1.route_id))) 
    as start_stop_name
	, coalesce(S2.name
				, (select stage_name 
				from stage SG 
				where SG.route_id=R.route_id 
				and SG.stage_id=(select max(SG1.stage_id) from stage SG1 where SG1.route_id=R.route_id group by SG1.route_id))) 
	as end_stop_name
	, case when T.direction=0 then 'Onward' else 'Return' end as direction
	, case when T.direction=0 then RST1.time else RST2.time end as departure_time
	, case when T.direction=0 then RST2.time else RST1.time end as arrival_time
	from route R
    left outer join stop S1 on (R.start_stop_id=S1.stop_id)
	left outer join stop S2 on (R.end_stop_id=S2.stop_id) 
	left outer join trip T on (R.route_id=T.route_id and T.fleet_id=in_fleet_id)
	left outer join routestop RS1 on (R.start_stop_id=RS1.stop_id and R.route_id=RS1.route_id)
	left outer join routestop RS2 on (R.end_stop_id=RS2.stop_id and R.route_id=RS2.route_id)
	left outer join routestoptrip RST1 on (RS1.route_stop_id=RST1.route_stop_id and RST1.trip_id=T.trip_id)
	left outer join routestoptrip RST2 on (RS2.route_stop_id=RST2.route_stop_id and RST2.trip_id=T.trip_id)

	where R.fleet_id = root_fleet_id
	and R.is_deleted=0
	/*and locate(depot, (select group_concat(internal_route_cd separator ',') from internal_route_map group by route_id having route_id=R.route_id)) > 0
*/
	order by (select case count(*) when 0 then 0 else 1 end from trip where route_id=R.route_id and fleet_id=in_fleet_id) desc
	, start_stop_name asc, end_stop_name asc, R.route_id asc, T.direction asc, departure_time asc
	;

end//

drop procedure if exists get_fleet_detail//
create procedure get_fleet_detail(in in_fleet_id int)
begin
	declare root_fleet_id, cur_fleet_id int;
	declare vfleet_name varchar(200);
	declare vavg_speed, vzoom int;
	declare	vcen_lat, vcen_lon, vne_lat, vne_lon ,vsw_lat ,vsw_lon float;
	declare vtrip_cnt int;

	
	select get_root_fleet(in_fleet_id) into root_fleet_id;
	set cur_fleet_id = in_fleet_id;

	hier: LOOP
		select 
			coalesce(vfleet_name, fleet_name)
			,coalesce(vavg_speed, avg_speed)
			,coalesce(vcen_lat, cen_lat)
			,coalesce(vcen_lon, cen_lon)
			,coalesce(vzoom, zoom)
			,coalesce(vne_lat, ne_lat)
			,coalesce(vne_lon, ne_lon)
			,coalesce(vsw_lat, sw_lat)
			,coalesce(vsw_lon, sw_lon)
		into vfleet_name,vavg_speed,vcen_lat,vcen_lon,vzoom,vne_lat,vne_lon,vsw_lat,vsw_lon
		from fleet 
		where fleet_id=cur_fleet_id;		

			
		if	vfleet_name is not null 
			and vavg_speed is not null 
			and vcen_lat is not null 
			and vcen_lon is not null 
			and vzoom is not null 
			and vne_lat is not null 
			and vne_lon is not null 
			and vsw_lat is not null 
			and vsw_lon is not null
		then
				leave hier;
		end if;	
			
		if cur_fleet_id = root_fleet_id then
			leave hier;
		end if;
	
		select parent_fleet_id into cur_fleet_id
		from fleet
		where fleet_id=cur_fleet_id
		and parent_fleet_id<>1;		
	END LOOP;

	select count(*) into vtrip_cnt
	from fleet F
	inner join trip T on (F.fleet_id=T.fleet_id)
	where F.fleet_id=in_fleet_id;
	
	select 
		in_fleet_id as fleet_id
		,vfleet_name as fleet_name
		,vavg_speed as avg_speed
		,vcen_lat as cen_lat
		,vcen_lon as cen_lon
		,vzoom as zoom
		,vne_lat as ne_lat
		,vne_lon as ne_lon
		,vsw_lat as sw_lat
		,vsw_lon as sw_lon
		,vtrip_cnt as trip_cnt;
	
	
	select stop_id,name,code,alias_name1,alias_name2,latitude,longitude,peer_stop_id, location_status
	from stop 
	where fleet_id=root_fleet_id
	order by stop_id;
	
	
	select 
	R.route_id as route_id
	, case R.route_name='ABC' or R.route_name is null 
		when true then convert(R.route_id using utf8) 
		else R.route_name
	end as route_name
    , (select group_concat(internal_route_cd separator ',') from internal_route_map where route_id=R.route_id group by route_id ) as internal_route_cd
	, coalesce(S1.name
                , (select SG.stage_name 
                from stage SG 
                where SG.route_id=R.route_id 
                and SG.sequence=(select min(SG1.sequence) from stage SG1 where SG1.route_id=R.route_id group by SG1.route_id))) 
    as start_stop_name
	, coalesce(S2.name
				, (select stage_name 
				from stage SG 
				where SG.route_id=R.route_id 
				and SG.sequence=(select max(SG1.sequence) from stage SG1 where SG1.route_id=R.route_id group by SG1.route_id))) as end_stop_name
, 
 (case 
	(S1.location_status<>0 
	and S2.location_status<>0 	
	and exists 
	(select *
		from routestop RS 		
		inner join stop S 
		where RS.stop_id=S.stop_id and RS.route_id=R.route_id and S.location_status=0		
	)	
	) 
	when true then 1 
	else 0 
	end ) * 16
| (select case count(*) when 0 then 0 else 1 end from trip where route_id=R.route_id and fleet_id=in_fleet_id limit 1) * 8
| (select case count(*) when 0 then 0 else 1 end from internal_route_map where route_id=R.route_id limit 1) * 4 
| (select case count(*) when 0 then 0 else 1 end from stage SG where SG.route_id=R.route_id limit 1) * 2 
| (select
	case 
		count(*)>0 
		and (count(*)=count(case when S.location_status<>0 then 1 end))  
	when true then 1 
	else 0
	end 
	from 
	routestop RS 
	inner join stop S on (RS.stop_id=S.stop_id) 
	where RS.route_id=R.route_id
	and S.fleet_id=root_fleet_id 
)
    as status
	from route R
    left outer join stop S1 on (R.start_stop_id=S1.stop_id)
	left outer join stop S2 on (R.end_stop_id=S2.stop_id)    
	where R.fleet_id = root_fleet_id
	and R.is_deleted=0
	/*order by (select case count(*) when 0 then 0 else 1 end from trip where route_id=R.route_id and fleet_id=in_fleet_id) desc*/
	/*having (root_fleet_id=7 and status >=16) or (root_fleet_id<>7)*/
	/*having (root_fleet_id=7 and locate('-',internal_route_cd,2)>0 and status>=16) or (root_fleet_id<>7)*/
	order by status desc
	, start_stop_name asc, end_stop_name asc, route_name asc
	;
	
	select * from calendar
	where fleet_id=root_fleet_id or fleet_id=1;
	
end//


drop procedure if exists save_route//
create procedure save_route(
	  INOUT id int
	, IN in_fleet_id int
	, IN in_route_name varchar(255)
    , IN in_internal_route_cd varchar(255)
	, IN in_start_stop int
	, IN in_end_stop int
	, IN in_gtfs_id int
	, IN in_sequence int
)
begin
    declare position int ;
    declare route_cd varchar(255) ;
    set position = 1;
    
if id = 0 then
	INSERT INTO route(fleet_id, route_name, start_stop_id, end_stop_id, gtfs_route_id) 
	VALUES (in_fleet_id, in_route_name, in_start_stop, in_end_stop, in_gtfs_id);
	set id = LAST_INSERT_ID() ;
else
	update route
	set route_name=in_route_name
	, start_stop_id=in_start_stop
	, end_stop_id=in_end_stop
	, gtfs_route_id=in_gtfs_id
	where route_id=id;
    

    

	delete from routestop
	where sequence > in_sequence 
	and route_id=id;
end if;

    delete from internal_route_map where route_id=id;
    
    l1: LOOP
        select SPLIT_STR(in_internal_route_cd, ',', position) into route_cd ;
        if(route_cd = '') then
            leave l1;
        end if;
            
        
        insert into internal_route_map values(id, route_cd);
        set position = position + 1;
    END LOOP l1;
end//

drop procedure if exists save_stage//
create procedure save_stage(
	INOUT id int
	, IN in_route_id int
	, IN in_stage_name varchar(255)
    , in in_is_via int
	, in in_sequence int
	, in in_stage_code varchar(255)
)
begin
if id > 0 then

	delete SG
	from stage SG
	left join routestop RS on (SG.stage_id=RS.stage_id and SG.route_id=RS.route_id)
	where SG.route_id=in_route_id and SG.sequence=in_sequence and SG.stage_id<> id
	and RS.route_stop_id is null
	;

	if exists (select * from stage where stage_id=id) then
		update stage
		set stage_name=in_stage_name, is_via=in_is_via, sequence=in_sequence, internal_stage_cd=in_stage_code
		where stage_id=id;
	else
		INSERT INTO stage(stage_id,stage_name, route_id,sequence, internal_stage_cd) 
        VALUES (id,in_stage_name, in_route_id, in_sequence, in_stage_code);
	end if;
else
	INSERT INTO stage(stage_name, route_id,sequence, internal_stage_cd) 
    VALUES (in_stage_name, in_route_id, in_sequence, in_stage_code);
	set id = LAST_INSERT_ID() ;
end if;
end//

drop procedure if exists save_route_stop//
create procedure save_route_stop(
	  IN in_stop_id int
	, IN in_return_stop_id int  
	, IN in_route_id int
	, IN in_stage_id int
	, IN in_sequence int
)
begin

/*Do any change only if needed */
if not exists (SELECT * FROM routestop WHERE stop_id = in_stop_id AND route_id=in_route_id and stage_id=in_stage_id and sequence=in_sequence) then
    /* If somebody else is in my place, remove him */
    delete RST
	from routestop RS
	left outer join routestoptrip RST on RS.route_stop_id=RST.route_stop_id
	where RS.stop_id<>in_stop_id and RS.route_id=in_route_id and RS.sequence=in_sequence;
	
	delete RS
	from routestop RS
	where RS.stop_id<>in_stop_id and RS.route_id=in_route_id and RS.sequence=in_sequence;
    
    if exists (SELECT * FROM routestop WHERE stop_id = in_stop_id AND route_id=in_route_id and sequence<in_sequence) 
        or not exists (SELECT * FROM routestop WHERE stop_id = in_stop_id AND route_id=in_route_id)
        then
        /* I am being re-added AFTER myself. If I am moved later in the sequence, I would not exist in the table */
        INSERT INTO routestop(stop_id, peer_stop_id, route_id, stage_id, sequence) 
        VALUES (in_stop_id, in_return_stop_id, in_route_id, in_stage_id, in_sequence);
    else
        if exists (SELECT * FROM routestop WHERE stop_id = in_stop_id AND route_id=in_route_id) then
            update routestop
            set stage_id=in_stage_id, sequence=in_sequence
            where stop_id = in_stop_id AND route_id=in_route_id;
        end if;        
    end if;    
end if;

/*
	delete RST
	from routestop RS
	left outer join routestoptrip RST on RS.route_stop_id=RST.route_stop_id
	where RS.stop_id<>in_stop_id and RS.route_id=in_route_id and RS.sequence=in_sequence;
	
	delete RS
	from routestop RS
	where RS.stop_id<>in_stop_id and RS.route_id=in_route_id and RS.sequence=in_sequence;


if exists (SELECT * FROM routestop WHERE stop_id = in_stop_id AND route_id=in_route_id) then
update routestop
set stage_id=in_stage_id, sequence=in_sequence
where stop_id = in_stop_id AND route_id=in_route_id;
else

INSERT INTO routestop(stop_id, peer_stop_id, route_id, stage_id, sequence) 
VALUES (in_stop_id, in_return_stop_id, in_route_id, in_stage_id, in_sequence);
end if;
*/
end//

drop procedure if exists get_route_detail//
create procedure get_route_detail(
	IN in_route_id int
)
begin
	select 
	R.route_id as route_id
	, R.route_name as route_name
    , (select group_concat(internal_route_cd separator ',') from internal_route_map group by route_id having route_id=R.route_id) as internal_route_cd
	, S1.name as start_stop_name
	, S2.name as end_stop_name
	, (select case count(*) when 0 then 0 else 1 end from trip where route_id=R.route_id ) as serviced
	from route R
	left outer join stop S1 on (R.start_stop_id= S1.stop_id)
	left outer join stop S2 on (R.end_stop_id=S2.stop_id)
	where R.route_id = in_route_id
	and R.is_deleted=0
	;
    
    
    /*select 
    SG.stage_id as stage_id
	, SG.stage_name as stage_name
    , SG.is_via as is_via
    from route R
    inner join stage SG on (SG.route_id=R.route_id)
    where R.route_id=in_route_id;
    */
	
	select SG.stage_id as stage_id
	, SG.stage_name as stage_name
    , SG.is_via as is_via
	, S.stop_id as onward_stop_id
	, S.name as onward_stop_name
	, if(S.code is null or S.code = '', null, S.code) as onward_stop_code
	, coalesce(BS.distance, 0) as onward_distance
	, PS.stop_id as return_stop_id
	, PS.name as return_stop_name
	, if(PS.code is null or PS.code = '', null, PS.code) as return_stop_code
	, coalesce(FS.distance, 0) as return_distance
	, S.is_station as is_station
	, SG.sequence
	, RS.sequence
	, SG.internal_stage_cd
	from route R
	inner join stage SG on (
		SG.route_id=R.route_id
		or
		SG.stage_id in (0,-1) and exists (select 1 from routestop where stage_id=SG.stage_id and route_id=R.route_id)
		)
        left outer join routestop RS on (RS.route_id=R.route_id and RS.stage_id=SG.stage_id )

/*	left outer join routestop RS on (RS.route_id=R.route_id )	*/
	left outer join stop S on (RS.stop_id=S.stop_id)	
/*
	inner join stage SG on (
		(SG.route_id=R.route_id and ((RS.stop_id is null) or (RS.stage_id=SG.stage_id)))
		or
		(RS.stage_id =0 and SG.stage_id=0)
	)
*/
	left outer join stop PS on (PS.stop_id=coalesce(RS.peer_stop_id,RS.stop_id))	
	
	left outer join routestop PRS on (PRS.route_id=R.route_id and RS.sequence = PRS.sequence+1)/* first routestop does not have a PRS*/
	left outer join segment BS on (BS.from_stop_id=PRS.stop_id and BS.to_stop_id=S.stop_id) 
	left outer join routestop NRS on (NRS.route_id=R.route_id and RS.sequence + 1 = NRS.sequence)/* last routestop does not have an NRS*/
	left outer join segment FS on (FS.from_stop_id=NRS.peer_stop_id and FS.to_stop_id=PS.stop_id) 	
	
	where R.route_id=in_route_id
	/*order by coalesce(SG.stage_id,0)*1000 + coalesce(RS.sequence, 0);*/
        /*order by coalesce(RS.sequence,SG.stage_id*1000);*/
        order by SG.sequence, coalesce(RS.sequence,0);
	
	select T.trip_id
	, T.fleet_id as fleet_id
	, T.calendar_id as service_id
	, T.direction
	, T.frequency_trip
	, T.frequency_start_time
	, T.frequency_end_time
	, T.frequency_gap
	from 
	route as R
	inner join trip as T on (R.route_id = T.route_id)
	where R.route_id = in_route_id
	order by T.trip_id;
	
	select T.trip_id, CASE T.direction WHEN 0 THEN RS.stop_id ELSE coalesce(RS.peer_stop_id,RS.stop_id) END as stop_id, RST.time
	from 
	route as R
	inner join trip as T on (R.route_id = T.route_id)
	inner join routestop as RS on (R.route_id=RS.route_id)
	inner join routestoptrip as RST on (RS.route_stop_id=RST.route_stop_id and T.trip_id=RST.trip_id)	
	where R.route_id=in_route_id
	order by T.trip_id, RS.sequence;
	
end//

drop procedure if exists get_missing_segments//
create procedure get_missing_segments(in in_route_id int)
begin
select RS1.stop_id as from_stop_id, S1.latitude as from_lat, S1.longitude as from_lon, RS2.stop_id as to_stop_id, S2.latitude as to_lat, S2.longitude as to_lon
from routestop RS1
inner join routestop RS2 on (RS1.route_id=RS2.route_id and RS1.sequence+1 = RS2.sequence)
inner join stop S1 on (RS1.stop_id=S1.stop_id)
inner join stop S2 on (RS2.stop_id=S2.stop_id)
left outer join segment SegOn on (S1.stop_id=SegOn.from_stop_id and S2.stop_id=SegOn.to_stop_id)
where SegOn.from_stop_id is null
and (RS1.route_id=in_route_id or in_route_id is null)

union  

select S1.stop_id as from_stop_id, S1.latitude as from_lat, S1.longitude as from_lon
, S2.stop_id as to_stop_id, S2.latitude as to_lat, S2.longitude as to_lon
from routestop RS1
inner join routestop RS2 on (RS1.route_id=RS2.route_id and RS1.sequence+1 = RS2.sequence)
inner join stop S1 on (coalesce(RS2.peer_stop_id, RS2.stop_id)=S1.stop_id)
inner join stop S2 on (coalesce(RS1.peer_stop_id, RS1.stop_id)=S2.stop_id)
left outer join segment SegOn on (S1.stop_id=SegOn.from_stop_id and S2.stop_id=SegOn.to_stop_id)
where SegOn.from_stop_id is null
and (RS1.route_id=in_route_id or in_route_id is null)

union 
select S1.stop_id as from_stop_id, S1.latitude as from_lat, S1.longitude as from_lon
, S2.stop_id as to_stop_id, S2.latitude as to_lat, S2.longitude as to_lon
from segment SG
inner join stop S1 on (SG.from_stop_id=S1.stop_id)
inner join stop S2 on (SG.to_stop_id=S2.stop_id)
where SG.is_stale=1
;
end//

drop procedure if exists add_segment//
create procedure add_segment(in in_from_stop_id int, in in_to_stop_id int, in_distance float)
begin
	insert into segment(from_stop_id, to_stop_id, distance)
	values(in_from_stop_id, in_to_stop_id, in_distance)
	on duplicate key update distance=in_distance, is_stale=0
	;
end//


drop procedure if exists save_trip//
create procedure save_trip(
	  INOUT id int
	, IN in_trip_name varchar(255)
	, IN in_calendar_id int  
	, IN in_direction boolean
	, IN in_route_id int
	, IN in_fleet_id int
	, IN in_frequency_trip boolean
	, IN in_frequency_start_time time
	, IN in_frequency_end_time time
	, IN in_frequency_gap time
)
begin
if id < 0 then
	INSERT INTO trip(trip_name, calendar_id, route_id, fleet_id, direction, frequency_trip, frequency_start_time, frequency_end_time, frequency_gap) 
	VALUES ('trip', in_calendar_id, in_route_id, in_fleet_id, in_direction, in_frequency_trip, in_frequency_start_time, in_frequency_end_time, in_frequency_gap);
	set id = LAST_INSERT_ID() ;
else
	UPDATE trip
	set trip_name = 'trip'
	, calendar_id = in_calendar_id
	, route_id = in_route_id
	, fleet_id = in_fleet_id
	, direction = in_direction
	, frequency_trip = in_frequency_trip
	, frequency_start_time = in_frequency_start_time
	, frequency_end_time = in_frequency_end_time
	, frequency_gap = in_frequency_gap
	where trip_id=id;
end if;
end//


drop procedure if exists save_route_stop_trip//
create procedure save_route_stop_trip(
	IN in_routeId int
	, IN in_stopId int
	, IN in_tripId int
	, IN in_time time
	, IN in_seq int
)
begin
declare rsid int;
if (in_seq=1) then
	SELECT route_stop_id into rsid
	FROM routestop 
	where (stop_id=in_stopId OR peer_stop_id=in_stopId) 
	AND route_id=in_routeId
	limit 1	;
else
	SELECT route_stop_id into rsid
	FROM routestop 
	where (stop_id=in_stopId OR peer_stop_id=in_stopId) 
	AND route_id=in_routeId
	limit 0,1	;
end if;

INSERT INTO routestoptrip(route_stop_id, trip_id, time) 
VALUES  (rsid, in_tripId, in_time)
on duplicate key update time=in_time;
end//

drop procedure if exists generate_stops//
create procedure generate_stops(in_fleet_id int)
begin
	declare lat, lon float;
	declare name varchar(255) ;
	declare f, cnt int  ;
	declare sid int ;

	declare vfleet_name varchar(200);
	declare vavg_speed, vzoom int;
	declare	vcen_lat, vcen_lon, vne_lat, vne_lon ,vsw_lat ,vsw_lon float;
	declare latinc, loninc float;
	
	select fleet_name,avg_speed,cen_lat,cen_lon,zoom,ne_lat,ne_lon,sw_lat,sw_lon 
	into vfleet_name,vavg_speed,vcen_lat,vcen_lon,vzoom,vne_lat,vne_lon,vsw_lat,vsw_lon
	from fleet 
	where fleet_id=in_fleet_id;
	
	set f = 1;
	set cnt = 1;
	/*set @sid = 0;*/
	/*set lat = 15.359118139929315; 
	set lon = 73.96272543945315;*/
	/*call save_stop( 0, name, lat, lon, 2, 0);*/
	
	set latinc = vne_lat - vsw_lat ;
	set loninc = vne_lon - vsw_lon ;
	while cnt < 5000 do
		set name := concat('stop', convert(cnt, char(50)));
		set sid := 0;
		set lat := vsw_lat + latinc * rand() ;
		set lon := vsw_lon + loninc * rand() ;
		
		if lat < 15.8 AND lat > 14.89833 AND lon < 74.336944 AND lon > 73.675833 then
		call save_stop(sid, name, lat, lon, 2, null,1);
		select sid;
		set f := -f;	
		set cnt := cnt + 1;
		end if;
	end while;
	
end//

drop procedure if exists get_stops//
create procedure get_stops(in in_fleet_id int)
begin
	declare root_fleet_id int;
	
	select get_root_fleet(in_fleet_id) into root_fleet_id;
	
	select stop_id,name,alias_name1,alias_name2,latitude,longitude,peer_stop_id 
	from stop
	where fleet_id=root_fleet_id
	order by stop_id;
	
end//


drop procedure if exists delete_trips//
create procedure delete_trips(
IN in_trip_id int
)
begin
DELETE FROM routestoptrip WHERE trip_id=in_trip_id;
DELETE FROM trip WHERE trip_id=in_trip_id;
end//

drop procedure if exists add_calendars//
create procedure add_calendars(
	IN in_fleet_id int
	,IN in_calendar_name varchar(25)
	,IN in_start_date DATE
	,IN in_end_date DATE
	,IN in_mon BOOLEAN
	,IN in_tue BOOLEAN
	,IN in_wed BOOLEAN
	,IN in_thu BOOLEAN
	,IN in_fri BOOLEAN
	,IN in_sat BOOLEAN
	,IN in_sun BOOLEAN
)
begin
insert into calendar(fleet_id,calendar_name,start_date,end_date,mon,tue,wed,thu,fri,sat,sun) VALUES (3,'FULLW','2015-10-02','2017-09-02',1,1,1,1,1,1,1);
end//

drop procedure if exists get_calendars//
create procedure get_calendars(
IN in_fleet_id int
)
begin
select * from calendar
where fleet_id=in_fleet_id or fleet_id=1;
end//

drop procedure if exists get_route_by_trips//
create procedure get_route_by_trips(
IN in_fleet_id int
)
begin
	select route_id, count(*)
	from trip
	where fleet_id=in_fleet_id	
	group by route_id
	order by count(*);
end//

drop function if exists CAP_FIRST//
CREATE FUNCTION CAP_FIRST (input VARCHAR(255) character set utf8 collate utf8_general_ci)

RETURNS VARCHAR(255) character set utf8 collate utf8_general_ci 

DETERMINISTIC

BEGIN
	DECLARE len INT;
	DECLARE i INT;

	SET len   = CHAR_LENGTH(input);
	SET input = LOWER(input);
	SET i = 0;

	WHILE (i < len) DO
		IF (MID(input,i,1) = ' ' OR MID(input,i,1) = '.' OR i = 0) THEN
			IF (i < len) THEN
				SET input = CONCAT(
					LEFT(input,i),
					UPPER(MID(input,i + 1,1)),
					RIGHT(input,len - i - 1)
				);
			END IF;
		END IF;
		SET i = i + 1;
	END WHILE;

	RETURN input;
END//

delimiter //
create or replace view vw_matching_routes_seq
as
select M.route_cd,
substring_index(group_concat( base_route_cd order by match_count desc),',',1) as matching_route_cd
from
(
select R1.route_id as route_id
, R1.route_cd as route_cd
, R1.route_name as route_name
, R2.route_id as base_route_id
, R2.route_cd as base_route_cd
, count(*) as match_count
from route R1 /*empty route*/
inner join stage SG1 on (SG1.route_id=R1.route_id)
inner join route R2 /*completed route*/
inner join stage SG2 on (SG2.route_id=R2.route_id)
where R1.route_id<>R2.route_id 
and R1.fleet_id=2 and R2.fleet_id=2
and 0=(select count(*) from routestop where route_id=R1.route_id)
and (select count(*) from routestop where route_id=R2.route_id)>0
and SG1.internal_stage_cd=SG2.internal_stage_cd and SG1.sequence=SG2.sequence
group by R1.route_id, R1.route_cd, R1.route_name
, R2.route_id, R2.route_cd, R2.route_name
having count(*)>=4 
order by R1.route_name, count(*) desc

) as M
group by M.route_cd
order by M.route_cd
//

create or replace view vw_route_segments
as
select R.route_id as route_id
, R.route_cd as route_cd
, SN.num as start_sequence
, EN.num as end_sequence
, group_concat( SG1.internal_stage_cd order by SG1.sequence separator '-') as stage_codes
, group_concat( SG1.internal_stage_cd order by SG1.sequence separator '-') as reverse_stage_codes
from stage SG1
inner join route R on (R.route_id=SG1.route_id)
inner join numbers SN on (SG1.sequence>=SN.num)
inner join numbers EN on (SN.num < EN.num and SG1.sequence <= EN.num)
where EN.num<= (select max(sequence) from stage where route_id=SG1.route_id)
and R.fleet_id=2
and (EN.num-SN.num) >= 3
-- and R.route_id in (5909,5982,6400)
group by SG1.route_id, SN.num, EN.num
//

create or replace view vw_matching_routes_seg
as
select 
VR1.route_id, VR1.route_cd
, convert(substring_index(group_concat( convert(VR1.start_sequence,char) order by length(VR2.stage_codes) desc),',',1), unsigned) as start_sequence
, convert(substring_index(group_concat( convert(VR1.end_sequence,char) order by length(VR2.stage_codes) desc),',',1), unsigned) as end_sequence
, convert(substring_index(group_concat( convert(VR2.route_id,char) order by length(VR2.stage_codes) desc),',',1), unsigned) as matching_route_id
, substring_index(group_concat( VR2.route_cd order by length(VR2.stage_codes) desc),',',1) as matching_route_cd
, convert(substring_index(group_concat( convert(VR2.start_sequence,char) order by length(VR2.stage_codes) desc),',',1), unsigned) as matching_start_sequence
, convert(substring_index(group_concat( convert(VR2.end_sequence,char) order by length(VR2.stage_codes) desc),',',1), unsigned) as matching_end_sequence
, substring_index(group_concat( VR2.stage_codes order by length(VR2.stage_codes) desc),',',1) as matching_stage_codes
from vw_route_segments as VR1
inner join vw_route_segments as VR2 on (VR1.stage_codes=VR2.stage_codes and VR1.route_id<>VR2.route_id)

where
    0=(select count(*) from routestop where route_id=VR1.route_id)
    and (select count(*) from routestop where route_id=VR2.route_id)>0
	and VR1.start_sequence=1 and VR2.start_sequence=1

group by VR1.route_id, VR1.route_cd
order by VR1.route_id, VR1.route_cd
//

drop procedure if exists get_tara_route_stops//
create procedure get_tara_route_stops()
begin
	select
	R.route_cd as route_cd
    , RS.sequence	
    , (select max(sequence) from routestop where routestop.route_id=RS.route_id) - RS.sequence + 1 as return_sequence
	, SG.stage_name as stage_name
    , SG.sequence as stage_sequence
    -- , 1 as status -- first stage is 1, last stage is 2
    , SG.internal_stage_cd as tara_stage_cd
    , S.stop_id as onward_stop_id
    , S.name as onward_stop_name	
    , S.latitude as onward_stop_lat
    , S.longitude as onward_stop_lon
    /* , ( select coalesce(RS.stop_id, RS.peer_stop_id)
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence limit 1)=S.stop_id as is_onward_first */
    , PS.stop_id as return_stop_id
    , PS.name as return_stop_name
    , PS.latitude as return_stop_lat
    , PS.longitude as return_stop_lon
    /* , ( select coalesce(RS.peer_stop_id, RS.stop_id) 
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence desc limit 1)=PS.stop_id as is_return_first */
	from route R
	left outer join routestop RS on (RS.route_id=R.route_id )	
	left outer join stop S on (RS.stop_id=S.stop_id)	
	inner join stage SG on (SG.route_id=R.route_id and ((RS.stop_id is null) or (RS.stage_id=SG.stage_id)))
	left outer join stop PS on (PS.stop_id=coalesce(RS.peer_stop_id,RS.stop_id))	
	
	left outer join routestop PRS on (PRS.route_id=R.route_id and RS.sequence = PRS.sequence+1)/* first routestop does not have a PRS*/
	left outer join segment BS on (BS.from_stop_id=PRS.stop_id and BS.to_stop_id=S.stop_id) 
	left outer join routestop NRS on (NRS.route_id=R.route_id and RS.sequence + 1 = NRS.sequence)/* last routestop does not have an NRS*/
	left outer join segment FS on (FS.from_stop_id=NRS.peer_stop_id and FS.to_stop_id=PS.stop_id) 	
	
	where R.fleet_id=2
    and RS.sequence is not null
    -- and R.route_cd='PRV79'
	order by 
    R.route_cd
    , RS.sequence
    ;
    -- , SG.stage_id*1000 + coalesce(RS.sequence, 0)
end//
-- call get_tara_route_stops()//

delimiter //
drop procedure if exists get_tara_route_stops_full//
create procedure get_tara_route_stops_full()
begin
	select
	IRM.internal_route_cd as route_cd
    , RS.sequence	
    , (select max(sequence) from routestop where routestop.route_id=RS.route_id) - RS.sequence + 1 as return_sequence
	, SG.stage_name as stage_name
    , SG.sequence as stage_sequence
    -- , 1 as status -- first stage is 1, last stage is 2
    , SG.internal_stage_cd as tara_stage_cd
    , S.stop_id as onward_stop_id
    , S.name as onward_stop_name	
    , S.latitude as onward_stop_lat
    , S.longitude as onward_stop_lon
    /* , ( select coalesce(RS.stop_id, RS.peer_stop_id)
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence limit 1)=S.stop_id as is_onward_first */
    , PS.stop_id as return_stop_id
    , PS.name as return_stop_name
    , PS.latitude as return_stop_lat
    , PS.longitude as return_stop_lon
    /* , ( select coalesce(RS.peer_stop_id, RS.stop_id) 
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence desc limit 1)=PS.stop_id as is_return_first */
	from route R
    inner join internal_route_map IRM on (IRM.route_id=R.route_id)
	left outer join routestop RS on (RS.route_id=R.route_id )	
	left outer join stop S on (RS.stop_id=S.stop_id)	
	inner join stage SG on (SG.route_id=R.route_id and ((RS.stop_id is null) or (RS.stage_id=SG.stage_id)))
	left outer join stop PS on (PS.stop_id=coalesce(RS.peer_stop_id,RS.stop_id))	
	
	left outer join routestop PRS on (PRS.route_id=R.route_id and RS.sequence = PRS.sequence+1)/* first routestop does not have a PRS*/
	left outer join segment BS on (BS.from_stop_id=PRS.stop_id and BS.to_stop_id=S.stop_id) 
	left outer join routestop NRS on (NRS.route_id=R.route_id and RS.sequence + 1 = NRS.sequence)/* last routestop does not have an NRS*/
	left outer join segment FS on (FS.from_stop_id=NRS.peer_stop_id and FS.to_stop_id=PS.stop_id) 	
	
	where R.fleet_id=2
    and RS.sequence is not null
    -- and R.route_cd='PRV79'
	order by 
    IRM.internal_route_cd
    , RS.sequence
    ;
    -- , SG.stage_id*1000 + coalesce(RS.sequence, 0)
end//
-- call get_tara_route_stops_full()//
    
delimiter //    
drop procedure if exists get_tara_route_stages//
create procedure get_tara_route_stages()
begin    
select R.route_cd, SG.internal_stage_cd, SG.sequence,
( select coalesce(RS.stop_id, RS.peer_stop_id)
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence limit 1) as onward_first_stop_id
,  (select coalesce(RS.stop_id, RS.peer_stop_id)
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence desc limit 1) as onward_last_stop_id
, ( select coalesce(RS.peer_stop_id, RS.stop_id) 
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence desc limit 1) as return_first_stop_id
, ( select coalesce(RS.peer_stop_id, RS.stop_id) 
from routestop RS 
where RS.stage_id=SG.stage_id 
order by RS.sequence limit 1) as return_last_stop_id
from route R
inner join stage SG on (SG.route_id=R.route_id)
where R.fleet_id=2
-- and R.route_cd='PRV79'
order by R.route_cd, SG.sequence
;
end//

-- n

-- call get_tara_route_stages()//

delimiter //    
drop procedure if exists get_tara_routes//
create procedure get_tara_routes(IN in_fleet_id int)
begin
SELECT 
R.route_cd
,F.gtfs_agency_id as agency_id
,'' as route_short_name
,concat( 
case when locate("EV ",SG1.stage_name)=1 then replace(SG1.stage_name, "EV ", "") else SG1.stage_name end
, " - "
,case when locate("EV ",SG2.stage_name)=1 then replace(SG2.stage_name, "EV ", "") else SG2.stage_name end 
) as route_name
/*
,CONCAT('"'
,coalesce(replace(S1.name, C1.old, C1.new), S1.name)
	, ' - ' 
,coalesce(replace(S2.name, C2.old, C2.new), S2.name)
	, coalesce(concat(cast(" via " as char character set utf8) 
		, (select group_concat(CAP_FIRST(SG.stage_name)) 
		from stage SG 
		where SG.route_id=R.route_id and SG.is_via=1
		group by SG.route_id)
	),"" )
	,'"')   as route_long_name
*/
,F.fleet_type as route_type
from route R
inner join stage SG1 on SG1.stage_id=(select SG.stage_id from stage SG where SG.route_id=R.route_id order by SG.sequence limit 1)
inner join stage SG2 on SG2.stage_id=(select SG.stage_id from stage SG where SG.route_id=R.route_id order by SG.sequence desc limit 1)
/*left outer join stage SG on (SG.route_id=R.route_id and SG.is_via=1)*/
-- inner join stop S1 on S1.stop_id=(select RS.stop_id from routestop RS where RS.route_id=R.route_id order by RS.sequence limit 1) 
-- left outer join corrections C1 on (S1.name like binary concat('%',C1.old,'%'))
-- inner join stop S2 on S2.stop_id=(select RS.stop_id from routestop RS where RS.route_id=R.route_id order by RS.sequence desc limit 1)
-- left outer join corrections C2 on (S2.name like binary concat('%',C2.old,'%'))
inner join fleet F on (in_fleet_id=F.fleet_id and (R.fleet_id=F.fleet_id or R.fleet_id=F.parent_fleet_id))
where (select count(*) from route Rx inner join stage SGx on (SGx.route_id=R.route_id) left outer join routestop RSx on (RSx.stage_id=Sgx.stage_id) where RSx.route_id is null) = 0
;
end//


/*
create or replace view vw_ktc_route as
SELECT concat('prv',M.erm_route_no) as erm_route_no , M.erm_start_stage , T.ert_route_via as ert_route_via , M.erm_end_stage , M.erm_no_of_stages ,  M.erm_route_type as erm_route_type, T.ert_route_type as ert_route_type , ST.est_bus_type   FROM prv.etm_route_master M    
inner join prv.etm_route_tran T  	on (T.ert_route_no=M.erm_route_no and T.ert_stage_no=1)   
left outer join prv.etm_service_type ST on (M.erm_bus_code=ST.est_bus_code)   
union all   
SELECT concat('mrg',M.erm_route_no) as erm_route_no , M.erm_start_stage , T.ert_route_via as ert_route_via , M.erm_end_stage , M.erm_no_of_stages ,  M.erm_route_type as erm_route_type, T.ert_route_type as ert_route_type , ST.est_bus_type   FROM mrg.etm_route_master M    inner join mrg.etm_route_tran T	on (T.ert_route_no=M.erm_route_no and T.ert_stage_no=1)   
left outer join mrg.etm_service_type ST on (M.erm_bus_code=ST.est_bus_code)   
union all   
SELECT concat('pnj',M.erm_route_no) as erm_route_no , M.erm_start_stage , T.ert_route_via as ert_route_via , M.erm_end_stage , M.erm_no_of_stages ,  M.erm_route_type as erm_route_type, T.ert_route_type as ert_route_type , ST.est_bus_type   FROM pnj.etm_route_master M      inner join pnj.etm_route_tran T	on (T.ert_route_no=M.erm_route_no and T.ert_stage_no=1)   
left outer join pnj.etm_service_type ST on (M.erm_bus_code=ST.est_bus_code)   
union all   
SELECT concat('vsg',M.erm_route_no) as erm_route_no , M.erm_start_stage , T.ert_route_via as ert_route_via , M.erm_end_stage , M.erm_no_of_stages ,  M.erm_route_type as erm_route_type, T.ert_route_type as ert_route_type , ST.est_bus_type FROM vsg.etm_route_master M    inner join vsg.etm_route_tran T	on (T.ert_route_no=M.erm_route_no and T.ert_stage_no=1)   
left outer join vsg.etm_service_type ST on (M.erm_bus_code=ST.est_bus_code)   
;

create or replace view vw_ktc_route_tran as

SELECT distinct concat('prv', ert_route_no) as ert_route_no, ert_stage_no, ert_stage_code, ert_stage_name   
FROM prv.etm_route_tran    
union all   
SELECT distinct concat('mrg', ert_route_no) as ert_route_no, ert_stage_no, ert_stage_code, ert_stage_name   
FROM mrg.etm_route_tran    
union all   
SELECT distinct concat('pnj', ert_route_no) as ert_route_no, ert_stage_no, ert_stage_code, ert_stage_name   
FROM pnj.etm_route_tran    
union all   
SELECT distinct concat('vsg', ert_route_no) as ert_route_no, ert_stage_no, ert_stage_code, ert_stage_name   
FROM vsg.etm_route_tran    
;
*/

grant select on *.* to 'report'@'%' ;
grant execute on procedure get_tara_route_stops to 'report'@'%';
grant execute on procedure get_tara_route_stops_full to 'report'@'%';
grant execute on procedure get_tara_route_stages to 'report'@'%';
grant execute on procedure get_tara_routes to 'report'@'%';
