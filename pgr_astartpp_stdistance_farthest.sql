-- This code is the latest one. Although it's calculating closest A, B, and C two times but still faster. --

-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- Install "pgr_aStarFromAtoB" (https://github.com/Zia-/pgr_aStarFromAtoBviaC) function beforehand --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better and looping could be reduced by two --

create or replace function pgr_aStarTPP_stdistance_farthest(IN tbl character varying, 
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
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob(''|| quote_ident(tbl) || '', x1, y1, x2, y2) as pgr;
	RAISE NOTICE 'Route for the first time has been calculated';
	breakwhile := array_length($6,1);
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	ending_id = breakwhile + 2;
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	For i in 1..breakwhile 
		Loop
			via_id := i + 1;
			execute 'with distance as (
				select the_geom as geom_distance from individual_stops, route where id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1 
				)
				insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
				from '|| quote_ident(tbl) || '_vertices_pgr, distance ORDER BY the_geom <-> geom_distance limit 1;'; 
		end loop;
	RAISE NOTICE 'Matrix for the first route is ready';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	RAISE NOTICE 'TSP has been calculated for the first route';
	source_var := -1;
	sum_cost := 0;
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
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
	RAISE NOTICE 'Sum cost for the first route is %', sum_cost;
	create temporary table loop_mat (geom_loop geometry, id integer);
	For i in 1..breakwhile Loop
		execute  'insert into loop_mat (geom_loop, id) select the_geom, id from individual_stops, route where 
				id = '||$6[i]||' and 
				st_distance(st_transform(st_geomfromtext(''Point('||x1||' '||y1||')'', 4326),32635),st_transform(the_geom,32635))+st_distance(st_transform(st_geomfromtext(''Point('||x2||' '||y2||')'', 4326),32635),st_transform(the_geom,32635)) < '||sum_cost||'
				order by st_distance(geom_route, the_geom)'; 
	end loop;
	RAISE NOTICE 'Loop table has been generated';

	-- Delete this section below --
	/*total_loop := 1;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[1]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 101 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[2]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 102 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[3]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 103 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	RAISE NOTICE 'Total number of loops are %', total_loop;
	num := 0;*/
	-- Delete this section above --
	
	sql_loop1 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[1]||'';
	FOR rec_loop1 IN EXECUTE sql_loop1 
		Loop
			sql_loop2 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[2]||'';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					sql_loop3 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[3]||'';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							create temporary table matrix_sub (id integer, node_id integer, x double precision, y double precision);
							execute 'insert into matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
							execute 'insert into matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
							execute 'insert into matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
							execute 'insert into matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
							execute 'insert into matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
							sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from matrix_sub order by id'', 1, '||ending_id||')'; 
							source_var := -1;
							sum_cost_again := 0;		
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
										sum_cost_again := sum_cost_again + sum_cost_rec.summation;
									END IF;
								END LOOP;
							sum_cost_again := sum_cost_again * 1000;
							RAISE NOTICE 'Sum cost again has been calculated and is %', sum_cost_again;
							If (sum_cost_again < sum_cost) Then
								drop table matrix;
								create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
								insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
								sum_cost := sum_cost_again;
								RAISE NOTICE 'Found an exception';	
							Else
							END IF;
							drop table matrix_sub;
							num := num + 1;
							RAISE NOTICE 'Loops done are %', num;
						END Loop;
				End Loop;
		End Loop;
	RAISE NOTICE 'Final matrix has been obtained';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from	pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
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
	drop table route;
	drop table matrix;
	drop table loop_mat;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_stdistance_farthest('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)




















-- This is logically the best approach, but a bit slower than the latest one. --

-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- Install "pgr_aStarFromAtoB" (https://github.com/Zia-/pgr_aStarFromAtoBviaC) function beforehand --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --
-- In this code, temporary tables' creation could be replaced by something better and looping could be reduced by two --

create or replace function pgr_aStarTPP_stdistance_farthest(IN tbl character varying, 
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
	lp integer;
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
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob(''|| quote_ident(tbl) || '', x1, y1, x2, y2) as pgr;
	RAISE NOTICE 'Route for the first time has been calculated';
	breakwhile := array_length($6,1);
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	ending_id = breakwhile + 2;
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	For i in 1..breakwhile 
		Loop
			via_id := i + 1;
			execute 'with distance as (
				select the_geom as geom_distance from individual_stops, route where id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1 
				)
				insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
				from '|| quote_ident(tbl) || '_vertices_pgr, distance ORDER BY the_geom <-> geom_distance limit 1;'; 
		end loop;
	RAISE NOTICE 'Matrix for the first route is ready';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	RAISE NOTICE 'TSP has been calculated for the first route';
	source_var := -1;
	sum_cost := 0;
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
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
	RAISE NOTICE 'Sum cost for the first route is %', sum_cost;
	create temporary table loop_mat (geom_loop geometry, id integer);
	For i in 1..breakwhile Loop
		execute  'insert into loop_mat (geom_loop, id) select the_geom, id from individual_stops, route where 
				id = '||$6[i]||' and 
				st_distance(st_transform(st_geomfromtext(''Point('||x1||' '||y1||')'', 4326),32635),st_transform(the_geom,32635))+st_distance(st_transform(st_geomfromtext(''Point('||x2||' '||y2||')'', 4326),32635),st_transform(the_geom,32635)) < '||sum_cost||'
				order by st_distance(geom_route, the_geom)'; 
	end loop;
	RAISE NOTICE 'Loop table has been generated';

	-- Delete this section below --
	/*total_loop := 1;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[1]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 101 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[2]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 102 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[3]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 103 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	RAISE NOTICE 'Total number of loops are %', total_loop;
	num := 0;*/
	-- Delete this section above --
	
	sql_loop1 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[1]||'';
	lp := 0;
	FOR rec_loop1 IN EXECUTE sql_loop1 
		Loop 
			sql_loop2 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[2]||'';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					sql_loop3 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[3]||'';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							IF (lp = 0) then
								lp = 1;
							Else
								create temporary table matrix_sub (id integer, node_id integer, x double precision, y double precision);
								execute 'insert into matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
										from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
								execute 'insert into matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
										from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
								execute 'insert into matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
										from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
								execute 'insert into matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
										from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
								execute 'insert into matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
										from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
								sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from matrix_sub order by id'', 1, '||ending_id||')'; 
								source_var := -1;
								sum_cost_again := 0;		
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
											sum_cost_again := sum_cost_again + sum_cost_rec.summation;
										END IF;
									END LOOP;
								sum_cost_again := sum_cost_again * 1000;
								RAISE NOTICE 'Sum cost again has been calculated and is %', sum_cost_again;
								If (sum_cost_again < sum_cost) Then
									drop table matrix;
									create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
									insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
									sum_cost := sum_cost_again;
									RAISE NOTICE 'Found an exception';	
								Else
								END IF;
								drop table matrix_sub;
								num := num + 1;
								RAISE NOTICE 'Loops done are %', num;
							END IF;
						END Loop;
				End Loop;
		End Loop;
	RAISE NOTICE 'Final matrix has been obtained';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from	pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
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
	drop table route;
	drop table matrix;
	drop table loop_mat;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_stdistance_farthest('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)










































-- Following is an old approach, not using now --


-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- Install "pgr_aStarFromAtoB" (https://github.com/Zia-/pgr_aStarFromAtoBviaC) function beforehand --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation) --
-- DROP FUNCTION test(character varying,double precision,double precision,double precision,double precision,double precision[])

create or replace function pgr_aStarTPP_stdistance_farthest(IN tbl character varying, 
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
	sum_cost double precision;
	sum_cost_again double precision;
	sum_cost_rec record;
	sql_loop text;
	sql_loop1 text;
	sql_loop2 text;
	sql_loop3 text;
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	total_loop integer;
	num integer;
begin
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob('ways', x1, y1, x2, y2) as pgr;
	RAISE NOTICE 'Route for the first time has been calculated';
	breakwhile := array_length($6,1);
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	ending_id = breakwhile + 2;
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from ways_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	For i in 1..breakwhile Loop
		via_id := i + 1;
		execute  'with distance as (
			select st_makepoint(x, y) as geom_distance from individual_stops, route where id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1 
			)
			insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			from ways_vertices_pgr, distance ORDER BY the_geom <-> st_setsrid(geom_distance, 4326) limit 1;'; 
	end loop;
	RAISE NOTICE 'Matrix for the first route is ready';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	RAISE NOTICE 'TSP has been calculated for the first route';
	seq := 0;
	source_var := -1;
	sum_cost := 0;
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
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
	RAISE NOTICE 'Sum cost for the first route is %', sum_cost;
	create temporary table loop_mat (geom_loop geometry, id integer);
	For i in 1..breakwhile Loop
		execute  'insert into loop_mat (geom_loop, id) select the_geom, id from individual_stops, route where 
				id = '||$6[i]||' and 
				st_distance(st_transform(st_geomfromtext(''Point('||x1||' '||y1||')'', 4326),32635),st_transform(the_geom,32635))+st_distance(st_transform(st_geomfromtext(''Point('||x2||' '||y2||')'', 4326),32635),st_transform(the_geom,32635)) < '||sum_cost||'
				order by st_distance(geom_route, the_geom)'; 
	end loop;
	RAISE NOTICE 'Loop table has been generated';

	-- Delete this section below --
	total_loop := 1;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[1]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 101 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[2]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 102 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[3]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 103 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	RAISE NOTICE 'Total number of loops are %', total_loop;
	num := 0;
	-- Delete this section above --
	
	sql_loop1 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[1]||'';
	FOR rec_loop1 IN EXECUTE sql_loop1 
		Loop
			sql_loop2 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[2]||'';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					sql_loop3 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[3]||'';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							create temporary table matrix_sub (id integer, node_id integer, x double precision, y double precision);
							execute 'insert into matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
							execute 'insert into matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
							execute 'insert into matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
							execute 'insert into matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
							execute 'insert into matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
							sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from matrix_sub order by id'', 1, '||ending_id||')'; 
							seq := 0;
							source_var := -1;
							sum_cost_again := 0;		
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
										sum_cost_again := sum_cost_again + sum_cost_rec.summation;
									END IF;
								END LOOP;
							sum_cost_again := sum_cost_again * 1000;
							RAISE NOTICE 'Sum cost again has been calculated and is %', sum_cost_again;
							If (sum_cost_again < sum_cost) Then
								drop table matrix;
								create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
								insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
								RAISE NOTICE 'Found an exception';	
							Else
							END IF;
							drop table matrix_sub;
							num := num + 1;
							RAISE NOTICE 'Loops done are %', num;
						END Loop;
				End Loop;
		End Loop;
	RAISE NOTICE 'Final matrix has been obtained';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from	pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
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
	drop table route;
	drop table matrix;
	drop table loop_mat;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom into x1 from pgr_aStarTPP_stdistance_farthest('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103)











-- Following is not a good appraoch as it's doing too much "insert" operation and hence slow --


create or replace function pgr_aStarTPP_stdistance_farthest(IN tbl character varying, 
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
	sum_cost double precision;
	sum_cost_again double precision;	
	sql_tsp text;
	sql_astar text;
	sql_loop text;
	sql_loop1 text;
	sql_loop2 text;
	sql_loop3 text;
	sql_final text;
	rec_final record;
	rec_tsp record;
	node record;
	rec_astar record;	
	sum_cost_rec record;	
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	
begin
	create temporary table route (geom_route geometry);
	insert into route select st_union(pgr.geom) as geom_route from pgr_astarfromatob(''|| quote_ident(tbl) || '', x1, y1, x2, y2) as pgr;
	RAISE NOTICE 'Route for the first time has been calculated';
	breakwhile := array_length($6,1);
	create temporary table matrix (id integer, node_id integer, x double precision, y double precision);
	ending_id = breakwhile + 2;
	execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
	execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision from '|| quote_ident(tbl) || '_vertices_pgr 
		ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
	For i in 1..breakwhile 
		Loop
			via_id := i + 1;
			execute 'with distance as (
				select the_geom as geom_distance from individual_stops, route where id = '||$6[i]||' order by st_distance(geom_route, the_geom) limit 1 
				)
				insert into matrix (id, node_id, x, y) select '||via_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
				from '|| quote_ident(tbl) || '_vertices_pgr, distance ORDER BY the_geom <-> geom_distance limit 1;'; 
		end loop;
	RAISE NOTICE 'Matrix for the first route is ready';
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from
			pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
	RAISE NOTICE 'TSP has been calculated for the first route';
	create temporary table output (gid integer, name text, cost double precision, geom geometry);
	seq := 0;
	source_var := -1;
	--sum_cost := 0;
	RAISE NOTICE '1';
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
				RAISE NOTICE '3';
			Else
				execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
				target_var := node.node_id;
				execute 'insert into output (gid, name, cost, geom) SELECT gid, name, cost, the_geom 
						FROM ' ||
						'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
						|| 'length::double precision AS cost, '
						|| 'x1::double precision, y1::double precision,'
						|| 'x2::double precision, y2::double precision,'
						|| 'reverse_cost::double precision FROM '
						|| quote_ident(tbl) || ''', '
						|| source_var || ', ' || target_var 
						|| ' , true, true), '
						|| quote_ident(tbl) || ' WHERE id2 = gid ORDER BY seq';
				RAISE NOTICE '5';
				/*FOR rec_final IN EXECUTE sql_final
					Loop
						RAISE NOTICE '6';
						sum_cost := sum_cost + rec_final.cost;
						seq := seq + 1;
						execute 'insert into output (seq, gid, name, cost) values 
							('||seq||','||rec_final.gid||','||rec_final.name||','||rec_final.cost||')';
						RAISE NOTICE '7';
					End Loop;
				RAISE NOTICE '4';*/
			END IF;
		END LOOP;
	execute 'select sum(cost) as sum from output;' into rec_final;
	sum_cost := rec_final.sum * 1000;
	delete from matrix;
	RAISE NOTICE 'Sum cost for the first route is %', sum_cost;
	create temporary table loop_mat (geom_loop geometry, id integer);
	For i in 1..breakwhile Loop
		execute  'insert into loop_mat (geom_loop, id) select the_geom, id from individual_stops, route where 
				id = '||$6[i]||' and 
				st_distance(st_transform(st_geomfromtext(''Point('||x1||' '||y1||')'', 4326),32635),st_transform(the_geom,32635))+st_distance(st_transform(st_geomfromtext(''Point('||x2||' '||y2||')'', 4326),32635),st_transform(the_geom,32635)) < '||sum_cost||'
				order by st_distance(geom_route, the_geom)'; 
	end loop;
	RAISE NOTICE 'Loop table has been generated';

	-- Delete this section below --
	/*total_loop := 1;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[1]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 101 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[2]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 102 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	sql_loop1 := 'select count(*) as count from loop_mat where id = '||$6[3]||'';
	For rec_loop1 in execute sql_loop1
		Loop
			RAISE NOTICE 'Total number of 103 points are %', rec_loop1.count;
			total_loop := total_loop * rec_loop1.count;
		End Loop;
	RAISE NOTICE 'Total number of loops are %', total_loop;
	num := 0;*/
	-- Delete this section above --
	create temporary table output_sub (seq integer, gid integer, name text, cost double precision, geom geometry);
	sql_loop1 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[1]||'';
	FOR rec_loop1 IN EXECUTE sql_loop1 
		Loop
			sql_loop2 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[2]||'';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					sql_loop3 := 'select st_x(geom_loop) as x, st_y(geom_loop) as y, id from loop_mat where id = '||$6[3]||'';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							execute 'insert into matrix (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
							execute 'insert into matrix (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision 
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
							execute 'insert into matrix (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
							execute 'insert into matrix (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
							execute 'insert into matrix (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
									from ways_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
							sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from matrix order by id'', 1, '||ending_id||')'; 
							seq := 0;
							source_var := -1;
							sum_cost_again := 0;		
							FOR rec_tsp IN EXECUTE sql_tsp
								LOOP
									If (source_var = -1) Then
										execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
										source_var := node.node_id;
									Else
										execute 'select node_id from matrix where id = '||rec_tsp.id2||'' into node;
										target_var := node.node_id;
										execute 'insert into output_sub (gid, name, cost, geom) SELECT gid, name, cost, the_geom  
												FROM ' ||
												'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
												|| 'length::double precision AS cost, '
												|| 'x1::double precision, y1::double precision,'
												|| 'x2::double precision, y2::double precision,'
												|| 'reverse_cost::double precision FROM '
												|| quote_ident(tbl) || ''', '
												|| source_var || ', ' || target_var 
												|| ' , true, true), '
												|| quote_ident(tbl) || ' WHERE id2 = gid ORDER BY seq';
									END IF;
								END LOOP;
							execute 'select sum(cost) as sum from output_sub;' into rec_final;
							sum_cost_again := rec_final.sum * 1000;
							delete from matrix;
							RAISE NOTICE 'Sum cost again has been calculated and is %', sum_cost_again;
							If (sum_cost_again < sum_cost) Then
								drop table output;
								insert into output (gid, name, cost, geom) select gid, name, cost, geom from output_sub;
								drop table output_sub;
								--create temporary table output (seq integer, gid integer, name text, cost double precision, geom geometry);
								--insert into matrix (id, node_id, x, y) select id, node_id, x, y from matrix_sub;
								sum_cost := sum_cost_again;
								RAISE NOTICE 'Found an exception';	
							Else
							END IF;
							num := num + 1;
							RAISE NOTICE 'Loops done are %', num;
						END Loop;
				End Loop;
		End Loop;
	sql_final := 'select * from output';
	FOR rec_final IN EXECUTE sql_final
		Loop
			gid := rec_final.gid;
			name := rec_final.name;
			cost := rec_final.cost;
			geom := rec_final.geom;
			RETURN NEXT;
		End Loop;
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the matrix table or route table already exists --
	RAISE NOTICE 'Everything is done';
	drop table route;
	drop table matrix;
	drop table loop_mat;
	drop table output_sub;
	drop table output;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_stdistance_farthest('ways', 28.982554739, 41.0779097116,28.9868028902, 41.112309375, 101, 102, 103)



