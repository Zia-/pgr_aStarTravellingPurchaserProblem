-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better and looping could be reduced by two --

create or replace function pgr_aStarTPP_radial_search(IN tbl character varying, 
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
	rec_tsp record;
	node record;
	rec_astar record;	
	sum_cost_rec record;	
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	
begin
	breakwhile := array_length($6,1);
	ending_id = breakwhile + 2;
	create temporary table loop_nodes (id integer, x double precision, y double precision, geom geometry);
	For i in 1..breakwhile
		Loop
			execute 'insert into loop_nodes (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1;';
		End Loop;
	For i in 1..breakwhile
		Loop
			execute 'insert into loop_nodes (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1;';
		End Loop;
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	create temporary table matrix_sub (id integer, node_id integer, x double precision, y double precision);

	--Delete
	/*
	sql_loop1 := 'select count(*) as count from loop_nodes where id = '||$6[4]||'';
	for rec_loop1 in execute sql_loop1
		loop
			raise notice '104 is %', rec_loop1.count;
		end loop;
	*/
	--Delete
	
	sql_loop1 := 'select id, x, y from loop_nodes where id = '||$6[1]||'';
	sum_cost_old := 0;
	FOR rec_loop1 IN EXECUTE sql_loop1 
		Loop
			sql_loop2 := 'select id, x, y from loop_nodes where id = '||$6[2]||'';
			raise notice '1';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					sql_loop3 := 'select id, x, y from loop_nodes where id = '||$6[3]||'';
					raise notice '2';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							
							raise notice '3';
							execute 'insert into matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
							raise notice '4';
							execute 'insert into matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
							raise notice '5';
							execute 'insert into matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
							raise notice '6';
							execute 'insert into matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
							raise notice '7';
							execute 'insert into matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
							raise notice '8';
							sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from matrix_sub order by id'', 1, '||ending_id||')'; 
							raise notice 'hi';
							source_var := -1;
							sum_cost := 0;		
							FOR rec_tsp IN EXECUTE sql_tsp
								LOOP
									If (source_var = -1) Then
										execute 'select node_id from matrix_sub where id = '||rec_tsp.id2||'' into node;
										source_var := node.node_id;
									Else
										execute 'select node_id from matrix_sub where id = '||rec_tsp.id2||'' into node;
										target_var := node.node_id;
										execute 'SELECT sum(cost) as summation
												FROM ' ||
												'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
												|| 'length::double precision AS cost, '
												|| 'x1::double precision, y1::double precision,'
												|| 'x2::double precision, y2::double precision,'
												|| 'reverse_cost::double precision FROM '
												|| quote_ident(tbl) || ''', '
												|| source_var || ', ' || target_var 
												|| ' , true, true), '
												|| quote_ident(tbl) || ' WHERE id2 = gid' into sum_cost_rec;
										sum_cost := sum_cost + sum_cost_rec.summation;
									END IF;
								END LOOP;
							sum_cost := sum_cost * 1000;
							RAISE NOTICE 'Sum cost again has been calculated and is %', sum_cost;
							If (sum_cost_old = 0) Then
								--drop table matrix;
								
								insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
								sum_cost_old := sum_cost;
								--sum_cost := sum_cost_again;
								--RAISE NOTICE 'Found an exception';	
							Else
								If (sum_cost < sum_cost_old) then
									delete from matrix;
									insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
									sum_cost_old := sum_cost;
								Else
								END IF;
							END IF;
							delete from matrix_sub;
						END Loop;
				End Loop;
		End Loop;
	RAISE NOTICE 'Final matrix has been obtained';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from	pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	RAISE NOTICE 'Sum_cost %', sum_cost;
	RAISE NOTICE 'TSP of final matrix has been calculated';
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
		END LOOP;	
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the matrix table or route table already exists --
	RAISE NOTICE 'Everything is done';
	drop table loop_nodes;
	drop table matrix;
	drop table matrix_sub;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_radial_search('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)

