-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better and looping could be reduced by two --

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
	via_id integer;
	total_loop integer;
	source_var integer;
	num integer;
	target_var integer;
	sum_cost_old double precision;
	sum_cost double precision;
	sum_cost_again double precision;	
	sql_tsp text;
	sql_astar text;
	sql_loop text;
	sql_loop1 text;
	sql_loop2 text;
	sql_loop3 text;
	sql_codes text;
	rec_tsp record;
	node record;
	rec_astar record;	
	sum_cost_rec record;
	rec_loop record;	
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	rec_codes record;
	
begin
	breakwhile := array_length($6,1);
	create temporary table codes (sid serial, id_code integer);
	create temporary table vertex_points (sid serial, id_code integer, node_id integer, x double precision, y double precision, geom_ver geometry); 
	create temporary table final_vertex (sid serial, id_code integer, node_id integer, x double precision, y double precision, geom_ver_final geometry);
	For i in 1..breakwhile
		Loop
			execute 'insert into codes (id_code) values ('||$6[i]||')';
		End Loop;
	------------ Feed the starting points ways_vertex_pgr point ----------
	execute 'insert into final_vertex (node_id, x, y, geom_ver_final) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	-----------
	sql_codes := 'select * from codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
			vertex as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and st_azimuth(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
			order by st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), the_geom) limit 1)
			insert into vertex_points (id_code, node_id, x, y, geom_ver) select '||rec_codes.id_code||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from ways_vertices_pgr, vertex 
			ORDER BY the_geom <-> geoms limit 1';
		End Loop;
	execute 'insert into final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from vertex_points order by
		st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), geom_ver) limit 1';
	execute 'delete from vertex_points';
	-----------
	execute 'delete from codes where id_code = (select id_code from final_vertex where sid = currval(''final_vertex_sid_seq''))';
	execute 'select st_x(geom_ver_final) as x, st_y(geom_ver_final) as y from final_vertex where sid = currval(''final_vertex_sid_seq'')' into rec_loop;
	sql_codes := 'select * from codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
			vertex as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
			order by st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), the_geom) limit 1)
			insert into vertex_points (id_code, node_id, x, y, geom_ver) select '||rec_codes.id_code||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from ways_vertices_pgr, vertex 
			ORDER BY the_geom <-> geoms limit 1';
		End Loop;
	execute 'insert into final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from vertex_points order by
		st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), geom_ver) limit 1';
	execute 'delete from vertex_points';
	-----------
	execute 'delete from codes where id_code = (select id_code from final_vertex where sid = currval(''final_vertex_sid_seq''))';
	execute 'select st_x(geom_ver_final) as x, st_y(geom_ver_final) as y from final_vertex where sid = currval(''final_vertex_sid_seq'')' into rec_loop;
	sql_codes := 'select * from codes';
	For rec_codes in execute sql_codes
		Loop
			execute 'with main_azimuth as (select st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)) as main_angle),
			vertex as (select the_geom as geoms from individual_stops, main_azimuth where id = '||rec_codes.id_code||' and st_azimuth(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), the_geom) Not Between main_angle+1.5708 And main_angle+4.7124
			order by st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), the_geom) limit 1)
			insert into vertex_points (id_code, node_id, x, y, geom_ver) select '||rec_codes.id_code||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from ways_vertices_pgr, vertex 
			ORDER BY the_geom <-> geoms limit 1';
		End Loop;
	execute 'insert into final_vertex (id_code, node_id, x, y, geom_ver_final) select id_code, node_id, x, y, geom_ver from vertex_points order by
		st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||rec_loop.x||','||rec_loop.y||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), geom_ver) limit 1';
	execute 'delete from vertex_points';
	------------ Feed the Ending points ways_vertex_pgr point ----------
	execute 'insert into final_vertex (node_id, x, y, geom_ver_final) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-----------
	--------- Now we have all the points -----------
	sql_loop1 := 'select * from final_vertex';
	seq := 0;
	source_var := -1;
	For rec_loop1 in execute sql_loop1
		Loop
			If (source_var = -1) Then
				execute 'select node_id from final_vertex where sid = '||rec_loop1.sid||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from final_vertex where sid = '||rec_loop1.sid||'' into node;
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
				-- Extracting the geom obtained from each pair aStar() in a row by row manner and returning it back to the pgr_aStarTPP_stdistance_closest() --
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
				RETURN NEXT;
			END IF;
		End Loop;	
	drop table vertex_points;
	drop table final_vertex;
	drop table codes;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_greedy_search('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)







