SET SESSION group_concat_max_len=10000;
select R.route_id
, group_concat( distinct SG.internal_stage_cd order by SG.sequence separator '-') onw
, group_concat( distinct SG.internal_stage_cd order by SG.sequence desc separator '-') ret
, group_concat( distinct S.name order by RS.sequence separator '-') onward_stops
, group_concat( distinct S.name order by RS.sequence desc separator '-') return_stops
from stage SG
inner join route R on ( SG.route_id=R.route_id)
inner join routestop RS on (RS.route_id=R.route_id and RS.stage_id=SG.stage_id)	
inner join stop S on (RS.stop_id=S.stop_id)		
where R.fleet_id = 2
and internal_stage_cd is not null
group by R.route_id;

select
	R.route_id as tara_route_id
    , RS.sequence	
	, SG.stage_name as stage_name
    , SG.internal_stage_cd as tara_stage_cd
    , S.name as onward_stop_name	
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
	order by R.route_id, SG.stage_id*1000 + coalesce(RS.sequence, 0);

delimiter //


call get_tara_routes(3)
