-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- Install "pgr_aStarFromAtoB" (https://github.com/Zia-/pgr_aStarFromAtoBviaC) function beforehand --
-- The arguments are the table name, the starting and ending points' coord and the via points' ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --

create or replace function pgr_aStarTPP_stdistance_closest_1_via(IN tbl character varying,
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
	sql_tsp text;
	source_var integer;
	rec_tsp record;
	node record;
	target_var integer;
	sql_astar text;
	rec_astar record;
begin
	-- Calculate the astar shortest path between the starting and ending points using pgr_aStarFromAtoB() and store the data --
	-- in a temporary table "pgr_aStarTPP_stdistance_closest_route" --
	create temporary table pgr_aStarTPP_stdistance_closest_route (geom_route geometry);
	insert into pgr_aStarTPP_stdistance_closest_route select st_union(pgr.geom) as geom_route from pgr_astarfromatob(''|| quote_ident(tbl) || '', x1, y1, x2, y2) as pgr;
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- to know the closest points to the "geom_route", related to all those three via points. --
	-- ($6, 1) means that we are referring to the 6th argument and 1 means that the array is of one dimension --
	-- First array value will correspond to $6[1] --
	breakwhile := array_length($6,1);
	-- Create another temporary table which will hold the coordinates of the via points --
	create temporary table pgr_aStarTPP_stdistance_closest_matrix (id integer, node_id integer, x double precision, y double precision);
	-- First we need to insert the starting point's details into this pgr_aStarTPP_stdistance_closest_matrix table, then using the For Loop --
	-- we will feed the via points. Later on, we will insert the ending point's detaisls and will use this pgr_aStarTPP_stdistance_closest_matrix table for our pgr_tsp(). --
	-- We are defining this ending_id coz coordinates must be entered into the pgr_aStarTPP_stdistance_closest_matrix table (for pgr_tsp) in the order: --
	-- start, via, via, etc etc, end --
	ending_id = breakwhile + 2;
	execute 'insert into pgr_aStarTPP_stdistance_closest_matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	-- In the following For Loop, the increment is 1 and the i value is 1,2,3,etc, not 0,1,2,3,etc --
	For i in 1..breakwhile Loop
		via_id := i + 1;
		-- The below is for the buffer approach which has been abandoned --
		-- Calculate the via point details and insert them into the pgr_aStarTPP_stdistance_closest_matrix table using the "SELECT COALESCE" METHOD --
		-- In the following SQL the buffer values (i.e. 0.00025, 0.00050, 0.001 etc etc) will define the succession of the buffer increment in order --
		-- to find the closest via point wrt to the geom_route (which we have calculated above using the pgr_aStarFromAtoB()). Therefore it's crucial. --
		-- In the following SQL we will not use <-> operator as this only kicks in if one of the geometries is a constant (not in a subquery/cte). --
		-- e.g. 'SRID=3005;POINT(1011102 450541)'::geometry instead of a.geom. Since we will be using geom_route and the_geom columns, none of them is a constant. Hence not used. --
		-- The above is for the buffer approach which has been abandoned --
		-- I have used "st_distance" instead of making subsequent buffer since it's more faster than buffer creation. --
		-- If you are making a geometry, it will take more time. So I have tried to avoid that. Results are similar from both the approaches. Buffer code is included in the comment as follows --
		/*
		execute  'with buffer as (
			select coalesce(
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.00025) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.00050) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.001) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.002) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.004) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.008) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.02) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.04) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.08) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1),
			(select st_makepoint(x, y) from individual_stops, pgr_aStarTPP_stdistance_closest_route where st_dwithin(the_geom, geom_route, 0.2) and id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1)
			)
			as geom_buffer)
			insert into pgr_aStarTPP_stdistance_closest_matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			from ways_vertices_pgr, buffer ORDER BY the_geom <-> st_setsrid(geom_buffer, 4326) limit 1;';
		*/
		execute  'with distance as (
			select the_geom as geom_distance from individual_stops, pgr_aStarTPP_stdistance_closest_route where id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1
			)
			insert into pgr_aStarTPP_stdistance_closest_matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			from '|| quote_ident(tbl) || '_vertices_pgr, distance ORDER BY the_geom <-> geom_distance limit 1;';
	end loop;
	-- Insert the ending point's details into this pgr_aStarTPP_stdistance_closest_matrix table --
	execute 'insert into pgr_aStarTPP_stdistance_closest_matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-- Calculate the TSP from the above created pgr_aStarTPP_stdistance_closest_matrix table (from here onwards I am using the pgr_aStarFromAtoBviaC() approach (https://github.com/Zia-/pgr_aStarFromAtoBviaC)) --
	-- Better code structure will use pgr_aStarFromAtoBviaC() directly, instead of writing the same stuff again here --
	sql_tsp := 'select id as id2 from pgr_aStarTPP_stdistance_closest_matrix order by id';
	seq := 0;
	-- We have declared source_var initial value as -1, not 0, coz any positive number could be the node_id of a point in ways_vertices_pgr table. --
	-- But by making it negative, we are assuring that the following loop will enter only at the first time in the "If" section and no more later. --
	source_var := -1;
	-- This For Loop will give the info about the order in which the journey must be traversed from the starting to ending points through the via points --
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from pgr_aStarTPP_stdistance_closest_matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from pgr_aStarTPP_stdistance_closest_matrix where id = '||rec_tsp.id2||'' into node;
				target_var := node.node_id;
				-- Here we will calculate the shortest route between all the pairs of nodes using aStar(), which must be travelled in the order --
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
			END IF;
		END LOOP;
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the pgr_aStarTPP_stdistance_closest_matrix table or pgr_aStarTPP_stdistance_closest_route table already exists --
	drop table pgr_aStarTPP_stdistance_closest_route;
	drop table pgr_aStarTPP_stdistance_closest_matrix;
	return;
end;
$body$
language plpgsql volatile STRICT;

-- To use this function --
-- select geom from pgr_aStarTPP_stdistance_closest_1_via('ways', 28.97438,41.00311,28.95370,41.02163, 101)
