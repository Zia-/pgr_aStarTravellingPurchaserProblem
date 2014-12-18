-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
--DROP FUNCTION test(character varying,double precision,double precision,double precision,double precision,double precision[])

create or replace function test(IN tbl character varying, 
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
	--route_rec record;
	breakwhile integer;
	--coordarray float[] := array[28.95819,41.00749];
	--buffer_rec record;
	buffer double precision;
	ending_id integer;
	--arrayLengthHalf integer;
	via_id integer;
	--x1 double precision;
	--b integer;
	--y1 double precision;
	sql_matrix text;
	sql_tsp text;
	rec_matrix record;
	source_var integer;
	target_var integer; 
	--rec_tsp record;
	--source_var integer;
	--target_var integer;
	node record;
	sql_astar text;
	rec_tsp record;
	rec_astar record;
begin
	-- Calculate the shortest path between the starting and ending points using pgr_aStarFromAtoB() --
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob('ways', x1, y1, x2, y2) as pgr;
	-- Array length --
	breakwhile := array_length($6,1);
	-- Create a table which will hold the coordinates of the via points --
	ending_id = breakwhile + 2;
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	-- Calculate the via points using SELECT coalesce METHOD --
	For i in 1..breakwhile Loop
		via_id := i + 1;
		execute  'with buffer as (
			select coalesce(
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.00025) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.00050) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.001) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.002) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.004) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.008) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.02) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.04) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.08) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1),
			(select st_makepoint(x, y) where st_dwithin(the_geom, geom_route, 0.2) and id = '||$6[i]||' order by the_geom <-> geom_route limit 1)
			) as geom_buffer
			from individual_stops, route)
			insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			from ways_vertices_pgr, buffer ORDER BY the_geom <-> st_setsrid(geom_buffer, 4326) limit 1;'; 
		execute 'select x, y from individual_stops, route where st_dwithin(the_geom, geom_route, 1) and id = '||$6[i]||'' into rec_astar;
		RAISE NOTICE 'Calling cs_create_job(%)', rec_astar;
		--append_array(coordarray, rec_astar)
		i = i + 1;
	end loop;
	-- Calculate the TSP from the above created matrix table --
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	-- Extracting the geom values row by row --
	seq := 0;
	source_var := -1;
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				target_var := node.node_id;
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
	-- Drop the temporary table, otherwise the next time you will run the query it will show that the matrix table already exists --
	drop table route;
	drop table matrix;
	return;
end;
$body$
language plpgsql volatile STRICT;

-- select geom into xxx1 from test('ways', 28.97438,41.00311,28.95370,41.02163, 100, 101, 102)
