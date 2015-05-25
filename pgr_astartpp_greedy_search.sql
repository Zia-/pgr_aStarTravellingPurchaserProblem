-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better --

create or replace function pgr_aStarTPP_greedy_search(IN tbl character varying, 
IN x1 double precision,
IN y1 double precision,
IN x2 double precision,
IN y2 double precision,
variadic double precision[],
OUT seq integer, 
OUT gid integer, 
OUT name text,
OUT cost double precision,
OUT geom geometry
)
RETURNS SETOF record AS
$body$
declare
	breakwhile integer;
	ending_id integer;
	source_var integer;
	target_var integer;
	sql_astar text;
	sql_codes text;
	node record;
	rec_astar record;	
	rec_loop record;	
	rec_codes record;
begin
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- ($6, 1) means that we are referring to the 6th argument and 1 means that the array is of one dimension --
	-- First array value will correspond to $6[1] --
	breakwhile := array_length($6,1);
	-- This table will contain all the codes (like 101, 102) which the user has supplied --
	create temporary table pgr_aStarTPP_greedy_search_codes (sid serial, id_code integer);
	-- This table will contain the closest A, B, or C points wrt the line joining the starting and ending point. --
	-- Note that this starting and ending point will change with each passing loop and so are the via nodes (in the begining A, B, C; then may be A, C; then may be A.) --
	create temporary table pgr_aStarTPP_greedy_search_vertex_points (sid serial, id_code integer, node_id integer, x double precision, y double precision, geom_ver geometry); 
	-- This table will contain the final matrix which we will be using for astar routing. Note that we will not use pgr_tsp() atall anywhere, as this is a greedy approach. --
	create temporary table pgr_aStarTPP_greedy_search_final_vertex (sid serial, id_code integer, node_id integer, x double precision, y double precision, geom_ver_final geometry);
	-- Feeding the pgr_aStarTPP_greedy_search_codes table --
	For i in 1..breakwhile
		Loop
			execute 'insert into pgr_aStarTPP_greedy_search_codes (id_code) values ('||$6[i]||')';
		End Loop;
	-- Feed the starting point of ways_vertex_pgr point --
	execute 'insert into pgr_aStarTPP_greedy_search_final_vertex (node_id, x, y, geom_ver_final) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	-- First loop --
	sql_codes := 'select * from pgr_aStarTPP_greedy_search_codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
				vertex_front as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1),
				vertex_back as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), the_geom) Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1)
				insert into pgr_aStarTPP_greedy_search_vertex_points (id_code, node_id, x, y, geom_ver) (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_front 
				ORDER BY the_geom <-> geoms limit 1) UNION (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_back 
				ORDER BY the_geom <-> geoms limit 1)';
		End Loop;
	execute 'insert into pgr_aStarTPP_greedy_search_final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from pgr_aStarTPP_greedy_search_vertex_points order by
		st_distance(ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326), geom_ver)+st_distance(ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326), geom_ver) limit 1';
	-- We have to empty that pgr_aStarTPP_greedy_search_vertex_points temporary table --
	execute 'delete from pgr_aStarTPP_greedy_search_vertex_points';
	-- Now we will remove that id_code (like 101, 102) from the pgr_aStarTPP_greedy_search_codes table which has been considered during greedy approach. --
	-- currval() will find the last inserted row --
	execute 'delete from pgr_aStarTPP_greedy_search_codes where id_code = (select id_code from pgr_aStarTPP_greedy_search_final_vertex where sid = currval(''pgr_aStarTPP_greedy_search_final_vertex_sid_seq''))';
	-- Here we will define our new starting point --
	execute 'select st_x(geom_ver_final) as x, st_y(geom_ver_final) as y from pgr_aStarTPP_greedy_search_final_vertex where sid = currval(''pgr_aStarTPP_greedy_search_final_vertex_sid_seq'')' into rec_loop;
	-- Second loop --
	sql_codes := 'select * from pgr_aStarTPP_greedy_search_codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
				vertex_front as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326) limit 1),
				vertex_back as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326) limit 1)
				insert into pgr_aStarTPP_greedy_search_vertex_points (id_code, node_id, x, y, geom_ver) (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_front 
				ORDER BY the_geom <-> geoms limit 1) UNION (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_back 
				ORDER BY the_geom <-> geoms limit 1)';
		End Loop;
	execute 'insert into pgr_aStarTPP_greedy_search_final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from pgr_aStarTPP_greedy_search_vertex_points order by
		st_distance(ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326), geom_ver)+st_distance(ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326), geom_ver) limit 1';
	-- We have to empty that pgr_aStarTPP_greedy_search_vertex_points temporary table --
	execute 'delete from pgr_aStarTPP_greedy_search_vertex_points';
	-- Now we will remove that id_code (like 101, 102) from the pgr_aStarTPP_greedy_search_codes table which has been considered during greedy approach. --
	-- currval() will find the last inserted row --
	execute 'delete from pgr_aStarTPP_greedy_search_codes where id_code = (select id_code from pgr_aStarTPP_greedy_search_final_vertex where sid = currval(''pgr_aStarTPP_greedy_search_final_vertex_sid_seq''))';
	-- Here we will define our new starting point --
	execute 'select st_x(geom_ver_final) as x, st_y(geom_ver_final) as y from pgr_aStarTPP_greedy_search_final_vertex where sid = currval(''pgr_aStarTPP_greedy_search_final_vertex_sid_seq'')' into rec_loop;
	-- Third loop --
	sql_codes := 'select * from pgr_aStarTPP_greedy_search_codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
				vertex_front as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326) limit 1),
				vertex_back as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and 
				st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Between main_angle+1.5708 And main_angle+4.7124
				order by the_geom <-> ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326) limit 1)
				insert into pgr_aStarTPP_greedy_search_vertex_points (id_code, node_id, x, y, geom_ver) (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_front 
				ORDER BY the_geom <-> geoms limit 1) UNION (select '||rec_codes.id_code||', id, 
				st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex_back 
				ORDER BY the_geom <-> geoms limit 1)';
		End Loop;
	execute 'insert into pgr_aStarTPP_greedy_search_final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from pgr_aStarTPP_greedy_search_vertex_points order by
		st_distance(ST_GeometryFromText(''Point('||rec_loop.x||' '||rec_loop.y||')'', 4326), geom_ver)+st_distance(ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326), geom_ver) limit 1';
	-- We have to empty that pgr_aStarTPP_greedy_search_vertex_points temporary table --
	execute 'delete from pgr_aStarTPP_greedy_search_vertex_points';
	-- Feed the Ending point of ways_vertex_pgr point --
	execute 'insert into pgr_aStarTPP_greedy_search_final_vertex (node_id, x, y, geom_ver_final) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-- Now we have all the points --
	sql_codes := 'select * from pgr_aStarTPP_greedy_search_final_vertex';
	seq := 0;
	-- We have declared source_var initial value as -1, not 0, coz any positive number could be the node_id of a point in ways_vertices_pgr table. --
	-- But by making it negative, we are assuring that the following loop will enter only at the first time in the "If" section and no more later. --
	source_var := -1;
	-- This For Loop will give the info about the order in which the journey must be traversed from the starting to ending points through the via points --
	For rec_codes in execute sql_codes
		Loop
			If (source_var = -1) Then
				execute 'select node_id from pgr_aStarTPP_greedy_search_final_vertex where sid = '||rec_codes.sid||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from pgr_aStarTPP_greedy_search_final_vertex where sid = '||rec_codes.sid||'' into node;
				target_var := node.node_id;
				-- Here we will calculate the shortest route between all the pairs of nodes using aStar(), which must be travlled in the order --
				sql_astar := 'SELECT gid, the_geom, name, cost, source, target, 
						ST_Reverse(the_geom) AS flip_geom FROM ' ||
						'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
						|| 'length::double precision AS cost, '
						|| 'x1::double precision, y1::double precision,'
						|| 'x2::double precision, y2::double precision,'
						|| 'reverse_cost::double precision FROM '
						|| quote_ident(tbl) || ''', '
						|| source_var || ', ' || target_var 
						|| ' , true, true), '
						|| quote_ident(tbl) || ' WHERE id2 = gid ORDER BY seq';
				-- Extracting the geom obtained from each pair aStar() in a row by row manner and returning it back to the pgr_aStarTPP_greedy_search() --
				For rec_astar in execute sql_astar
					Loop
						seq := seq +1 ;
						gid := rec_astar.gid;
						name := rec_astar.name;
						cost := rec_astar.cost;
						geom := rec_astar.the_geom;
						RETURN NEXT;
					End Loop;
				source_var := target_var;
			END IF;
		End Loop;
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the pgr_aStarTPP_greedy_search_vertex_points, pgr_aStarTPP_greedy_search_final_vertex or pgr_aStarTPP_greedy_search_codes table already exists --	
	drop table pgr_aStarTPP_greedy_search_vertex_points;
	drop table pgr_aStarTPP_greedy_search_final_vertex;
	drop table pgr_aStarTPP_greedy_search_codes;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_greedy_search('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)







