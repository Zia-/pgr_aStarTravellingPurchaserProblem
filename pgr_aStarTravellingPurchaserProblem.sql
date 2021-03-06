-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table) --
-- DROP FUNCTION test(character varying,double precision,double precision,double precision,double precision,double precision[])

create or replace function pgr_aStarTravellingPurchaserProblem(IN tbl character varying, 
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
	-- Calculate the shortest path between the starting and ending points using pgr_aStarFromAtoB() and store the data --
	-- in the temporary table "route" (although I am not very happy with this temporary table appraoch) --
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob('ways', x1, y1, x2, y2) as pgr;
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- to know the closest points related to all those three via points --
	-- ($6, 1) means that the 6th argument and the array is of dimension one --
	breakwhile := array_length($6,1);
	-- Create another temporary table which will hold the coordinates of the via points --
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	-- First we need to insert the starting and ending points details into this matrix table, then using the For Loop --
	-- we will feed the via points. Later on, we will use this matrix table for our pgr_tsp() --
	ending_id = breakwhile + 2;
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-- Calculate the via points details and inserting them into the matrix table using the "SELECT COALESCE" METHOD --
	For i in 1..breakwhile Loop
		via_id := i + 1;
		-- In the following SQL the buffer values (i.e. 0.00025, 0.00050, 0.001 etc etc) will define the succession of the buffer increment in order --
		-- to find the closest via point wrt to the route (which we have calculate using the pgr_aStarFromAtoB()). Therefor it's crucial --
		execute  'with buffer as (
			select coalesce(
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.00025) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.00050) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.001) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.002) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.004) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.008) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.02) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.04) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.08) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) from individual_stops, route where st_dwithin(the_geom, geom_route, 0.2) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1)
			) 
			as geom_buffer)
			insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			from ways_vertices_pgr, buffer ORDER BY the_geom <-> st_setsrid(geom_buffer, 4326) limit 1;'; 
		i = i + 1;
	end loop;
	-- Calculate the TSP from the above created matrix table (from here onwards I am using the pgr_aStarFromAtoBviaC() approach) --
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	-- Here declaring few variables which will be used in the For Loop, later on --
	seq := 0;
	source_var := -1;
	-- This For Loop will give the info about the order in which the journey must be traversed from the starting to ending points through the via points --
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
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
				-- Extracting the geom obtained from each pair aStar() in a row by row manner and returning it back to the pgr_aStarTravellingPurchaserProblem() --
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
		END LOOP;	
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the matrix table or route table already exists --
	drop table route;
	drop table matrix;
	return;
end;
$body$
language plpgsql volatile STRICT;

-- To use this function --
-- select geom from pgr_aStarTravellingPurchaserProblem('ways', 28.97438,41.00311,28.95370,41.02163, 100, 101, 102)
