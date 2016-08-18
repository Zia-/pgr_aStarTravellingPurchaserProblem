-- THE FOLLOWING PROCEDURAL FUNCTION WILL SOLVE OUR TRAVELLING PURCHASER PROBLEM --
-- The arguments are the table name, the starting and ending points coord and the via points ids (which we have defined in
-- the individual_stops table - Consult the Documentation of this repo) --

create or replace function pgr_aStarTPP_radial_search_directline_sorting_4_via(IN tbl character varying,
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
	total_loop integer;
	source_var integer;
	target_var integer;
	sum_cost_old double precision;
	sum_cost double precision;
	sql_tsp text;
	sql_astar text;
	sql_loop1 text;
	sql_loop2 text;
	sql_loop3 text;
	sql_loop4 text;
	rec_tsp record;
	node record;
	rec_astar record;
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	rec_loop4 record;

begin
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- ($6, 1) means that we are referring to the 6th argument and 1 means that the array is of one dimension --
	-- First array value will correspond to $6[1] --
	breakwhile := array_length($6,1);
	ending_id = breakwhile + 2;
	-- pgr_aStarTPP_radial_search_loop_nodes_rubbish will hold the closest two A, B, and C wrt to the start and end points --
	create temporary table pgr_aStarTPP_radial_search_loop_nodes_rubbish (id integer, x double precision, y double precision, geom geometry);
	-- pgr_aStarTPP_radial_search_loop_nodes table will store the cloest A, B, and C nodes wrt to the start and end points --
	create temporary table pgr_aStarTPP_radial_search_loop_nodes (id integer, x double precision, y double precision, geom geometry);
	-- Feed the pgr_aStarTPP_radial_search_loop_nodes table with those A, B, and C nodes which are cloest to the start point --
	For i in 1..breakwhile
		Loop
			execute 'insert into pgr_aStarTPP_radial_search_loop_nodes_rubbish (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 2;';
		End Loop;
	-- Feed the pgr_aStarTPP_radial_search_loop_nodes table with those A, B, and C nodes which are cloest to the end point --
	For i in 1..breakwhile
		Loop
			execute 'insert into pgr_aStarTPP_radial_search_loop_nodes_rubbish (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 2;';
		End Loop;

-------------------
	-- Now run the For loop to find the closest A, B, and C points to the direct line joining start-end point --
	For i in 1..breakwhile
		Loop
			execute 'with vertex as (select id, x, y, geom from pgr_aStarTPP_radial_search_loop_nodes_rubbish where id = '||$6[i]||'
			order by st_distance(ST_MakeLine(st_setsrid(ST_MakePoint('||x1||','||y1||'),4326), st_setsrid(ST_MakePoint('||x2||','||y2||'),4326)), geom) limit 1)
			insert into pgr_aStarTPP_radial_search_loop_nodes (id, x, y, geom) select id, x, y, geom from vertex limit 1';
		End Loop;
-------------------

	-- This pgr_aStarTPP_radial_search_matrix table will store the shortest route combination of A, B, and C nodes --
	create temporary table pgr_aStarTPP_radial_search_matrix (id integer, node_id integer, x double precision, y double precision);
	-- This pgr_aStarTPP_radial_search_matrix_sub table will store all possible combinations of A, B, and C nodes, coming from the pgr_aStarTPP_radial_search_loop_nodes table --
	create temporary table pgr_aStarTPP_radial_search_matrix_sub (id integer, node_id integer, x double precision, y double precision);
	-- This variable will hold the length value for all the possible combinations --
	sum_cost_old := 0;
	-- Here we will select those records which belongs to the $6[1] array value --
	sql_loop1 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[1]||'';
	FOR rec_loop1 IN EXECUTE sql_loop1
		Loop
			-- Here we will select those records which belongs to the $6[2] array value --
			sql_loop2 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[2]||'';
			FOR rec_loop2 IN EXECUTE sql_loop2
				Loop
					-- Here we will select those records which belongs to the $6[3] array value --
					sql_loop3 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[3]||'';
					FOR rec_loop3 IN EXECUTE sql_loop3
						Loop
							-- Here we will select those records which belongs to the $6[3] array value --
							sql_loop4 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[4]||'';
							FOR rec_loop4 IN EXECUTE sql_loop4
								Loop


									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 5, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop4.x||' '||rec_loop4.y||')'', 4326) limit 1;';
									execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
											from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
									-- Calculate the pgr_tsp for each combination of A, B, and C. --
									sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from pgr_tsp(''select id, x, y from pgr_aStarTPP_radial_search_matrix_sub order by id'', 1, '||ending_id||')';
									-- We have declared source_var initial value as -1, not 0, coz any positive number could be the node_id of a point in ways_vertices_pgr table. --
									-- But by making it negative, we are assuring that the following loop will enter only at the first time in the "If" section and no more later. --
									source_var := -1;
									sum_cost := 0;
									-- Calculate the length of each route and append it to the final sum_cost variable, which we will compare with the sum_cost_old value --
									FOR rec_tsp IN EXECUTE sql_tsp
										LOOP
											If (source_var = -1) Then
												execute 'select node_id from pgr_aStarTPP_radial_search_matrix_sub where id = '||rec_tsp.id2||'' into node;
												source_var := node.node_id;
											Else
												execute 'select node_id from pgr_aStarTPP_radial_search_matrix_sub where id = '||rec_tsp.id2||'' into node;
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
														|| quote_ident(tbl) || ' WHERE id2 = gid' into node;
												sum_cost := sum_cost + node.summation;
												source_var := target_var;
											END IF;
										END LOOP;
									If (sum_cost_old = 0) Then
										-- Feeding pgr_aStarTPP_radial_search_matrix table for the first time --
										insert into pgr_aStarTPP_radial_search_matrix (id, node_id, x, y) select id, node_id, x, y from pgr_aStarTPP_radial_search_matrix_sub;
										-- Making sum_cost_old value our sum_cost value --
										sum_cost_old := sum_cost;
									Else
										-- If newly calculated sum_cost is smaller than the smallest sum_cost_old, we have calculated so far, then go into this If --
										If (sum_cost < sum_cost_old) then
											-- Delete all rows from pgr_aStarTPP_radial_search_matrix table --
											delete from pgr_aStarTPP_radial_search_matrix;
											-- Insert this new pgr_aStarTPP_radial_search_matrix combination which is even more smaller than our smallest route nodes combination --
											insert into pgr_aStarTPP_radial_search_matrix (id, node_id, x, y) select id, node_id, x, y from pgr_aStarTPP_radial_search_matrix_sub;
											-- Making sum_cost_old value our sum_cost value --
											sum_cost_old := sum_cost;
										Else
										END IF;
									END IF;
									-- Empty pgr_aStarTPP_radial_search_matrix_sub table to handle another A, B, and C combination --
									delete from pgr_aStarTPP_radial_search_matrix_sub;
								END Loop;
						END Loop;
				End Loop;
		End Loop;
	-- Now calculate the final pgr_tsp() for our best combination of A, B, and C matrix --
	sql_tsp := 'select seq, id1, id2, round(cost::numeric, 5) AS cost from	pgr_tsp(''select id, x, y from pgr_aStarTPP_radial_search_matrix order by id'', 1, '||ending_id||')';
	seq := 0;
	-- We have declared source_var initial value as -1, not 0, coz any positive number could be the node_id of a point in ways_vertices_pgr table. --
	-- But by making it negative, we are assuring that the following loop will enter only at the first time in the "If" section and no more later. --
	source_var := -1;
	-- This For Loop will give the info about the order in which the journey must be traversed from the starting to ending points through the via points --
	FOR rec_tsp IN EXECUTE sql_tsp
		LOOP
			If (source_var = -1) Then
				execute 'select node_id from pgr_aStarTPP_radial_search_matrix where id = '||rec_tsp.id2||'' into node;
				source_var := node.node_id;
			Else
				execute 'select node_id from pgr_aStarTPP_radial_search_matrix where id = '||rec_tsp.id2||'' into node;
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
				-- Extracting the geom obtained from each pair aStar() in a row by row manner and returning it back to the pgr_aStarTPP_radial_search() --
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
	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the pgr_aStarTPP_radial_search_matrix, pgr_aStarTPP_radial_search_loop_nodes or pgr_aStarTPP_radial_search_matrix_sub table already exists --
	drop table pgr_aStarTPP_radial_search_loop_nodes_rubbish;
	drop table pgr_aStarTPP_radial_search_loop_nodes;
	drop table pgr_aStarTPP_radial_search_matrix;
	drop table pgr_aStarTPP_radial_search_matrix_sub;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select geom from pgr_aStarTPP_radial_search_directline_sorting_4_via('ways', 29.104768000000000,41.027425000000001,29.122485000000001,41.048262999999999, 101, 102, 103, 104)
