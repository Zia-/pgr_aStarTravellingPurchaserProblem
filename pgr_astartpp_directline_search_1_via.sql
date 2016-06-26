-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better and looping could be reduced by two --

create or replace function pgr_aStarTPP_directline_search_1_via(IN tbl character varying,
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
	sql_tsp text;
	sql_astar text;
	rec_tsp record;
	node record;
	rec_astar record;
begin
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- ($6, 1) means that we are referring to the 6th argument and 1 means that the array is of one dimension --
	-- First array value will correspond to $6[1] --
	breakwhile := array_length($6,1);
	ending_id = breakwhile + 2;
	-- This table will contain the final matrix which we will be using in pgr_tsp().
	create temporary table pgr_aStarTPP_directline_search_vertex_points (sid serial, node_id integer, x double precision, y double precision, geom_ver geometry);
	-- Feed the starting point of ways_vertex_pgr point --
	execute 'insert into pgr_aStarTPP_directline_search_vertex_points (node_id, x, y, geom_ver) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	-- Now rum the For loop to find the closest A, B, and C points to the direct line joining start-end point --
	For i in 1..breakwhile
		Loop
			execute 'with vertex as (select the_geom as geoms from individual_stops where id = '||$6[i]||'
			order by st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), the_geom) limit 1)
			insert into pgr_aStarTPP_directline_search_vertex_points (node_id, x, y, geom_ver) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr, vertex
			ORDER BY the_geom <-> geoms limit 1';
		End Loop;
	-- Feed the ending point of ways_vertex_pgr point --
	execute 'insert into pgr_aStarTPP_directline_search_vertex_points (node_id, x, y, geom_ver) select id, st_x(the_geom)::double precision, st_y(the_geom)::double precision, the_geom from '|| quote_ident(tbl) || '_vertices_pgr
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-- Now calculate the final pgr_tsp() for this combination of A, B, and C matrix --
	sql_tsp := 'select sid as id2 from pgr_aStarTPP_directline_search_vertex_points order by sid';
	seq := 0;
	-- We have declared source_var initial value as -1, not 0, coz any positive number could be the node_id of a point in ways_vertices_pgr table. --
	-- But by making it negative, we are assuring that the following loop will enter only at the first time in the "If" section and no more later. --
	source_var := -1;
	-- This For Loop will give the info about the order in which the journey must be traversed from the starting to ending points through the via points --
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from pgr_aStarTPP_directline_search_vertex_points where sid = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from pgr_aStarTPP_directline_search_vertex_points where sid = '||rec_tsp.id2||'' into node;
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
				-- Extracting the geom obtained from each pair aStar() in a row by row manner and returning it back to the pgr_aStarTPP_directline_search() --
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
		END LOOP;
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the pgr_aStarTPP_directline_search_vertex_points table already exists --
	drop table pgr_aStarTPP_directline_search_vertex_points;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_directline_search_1_via('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101)
