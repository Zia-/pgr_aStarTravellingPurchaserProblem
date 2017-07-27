create or replace function pgr_aStarTPP_radial_search_1_via_BESTSelection(IN tbl character varying,
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
	sql_loop5 text;
	rec_tsp record;
	node record;
	rec_astar record;
	rec_loop1 record;
	rec_loop2 record;
	rec_loop3 record;
	rec_loop4 record;
	rec_loop5 record;

begin
	-- Following is the Array length which we need to know for the For Loop. --
	-- If the Array length is 3 then it means that there are three via points and Loop has to run for three times --
	-- ($6, 1) means that we are referring to the 6th argument and 1 means that the array is of one dimension --
	-- First array value will correspond to $6[1] --
	breakwhile := array_length($6,1);
	ending_id = breakwhile + 2;
	-- pgr_aStarTPP_radial_search_loop_nodes table will store the cloest A, B, and C nodes wrt to the start and end points --
	create temporary table pgr_aStarTPP_radial_search_loop_nodes (id integer, x double precision, y double precision, geom geometry);
	-- Feed the pgr_aStarTPP_radial_search_loop_nodes table with those A, B, and C nodes which are cloest to the start point --
	For i in 1..breakwhile
		Loop
			execute 'insert into pgr_aStarTPP_radial_search_loop_nodes (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1;';
		End Loop;
	-- Feed the pgr_aStarTPP_radial_search_loop_nodes table with those A, B, and C nodes which are cloest to the end point --
	For i in 1..breakwhile
		Loop
			execute 'insert into pgr_aStarTPP_radial_search_loop_nodes (id, x, y, geom) select id, x, y, the_geom from individual_stops where id = '||$6[i]||' order by the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1;';
		End Loop;
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
			--sql_loop2 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[2]||'';
			--FOR rec_loop2 IN EXECUTE sql_loop2
			--	Loop
					-- Here we will select those records which belongs to the $6[3] array value --
			--		sql_loop3 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[3]||'';
			--		FOR rec_loop3 IN EXECUTE sql_loop3
			--			Loop
							-- Here we will select those records which belongs to the $6[3] array value --
			--				sql_loop4 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[4]||'';
			--				FOR rec_loop4 IN EXECUTE sql_loop4
			--					Loop
									-- Here we will select those records which belongs to the $6[5] array value --
			--						sql_loop5 := 'select id, x, y from pgr_aStarTPP_radial_search_loop_nodes where id = '||$6[5]||'';
			--						FOR rec_loop5 IN EXECUTE sql_loop5
			--							Loop


			execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 1, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
					from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x1||' '||y1||')'', 4326) limit 1';
			execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 2, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
					from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop1.x||' '||rec_loop1.y||')'', 4326) limit 1;';
			--execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 3, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			--		from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop2.x||' '||rec_loop2.y||')'', 4326) limit 1;';
			--execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 4, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			--		from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop3.x||' '||rec_loop3.y||')'', 4326) limit 1;';
			--execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 5, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			--		from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop4.x||' '||rec_loop4.y||')'', 4326) limit 1;';
			--execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select 6, id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
			--		from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||rec_loop5.x||' '||rec_loop5.y||')'', 4326) limit 1;';
			execute 'insert into pgr_aStarTPP_radial_search_matrix_sub (id, node_id, x, y) select '||ending_id||', id, st_x(the_geom)::double precision, st_y(the_geom)::double precision
					from '|| quote_ident(tbl) || '_vertices_pgr ORDER BY the_geom <-> ST_GeometryFromText(''Point('||x2||' '||y2||')'', 4326) limit 1';
			-- Calculate the pgr_tsp for each combination of A, B, and C. --
			sql_tsp := 'select id as id2 from pgr_aStarTPP_radial_search_matrix_sub order by id';
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
						execute 'SELECT sum(pgr.cost) as summation
								FROM ' ||
								'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
								|| 'length::double precision AS cost, '
								|| 'x1::double precision, y1::double precision,'
								|| 'x2::double precision, y2::double precision,'
								|| 'reverse_cost::double precision FROM '
								|| quote_ident(tbl) || ''', '
								|| source_var || ', ' || target_var
								|| ' , true, true) as pgr, '
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
			--							END Loop;
			--					END Loop;
			--			END Loop;
			--	End Loop;
		End Loop;
	-- Now calculate the final pgr_tsp() for our best combination of A, B, and C matrix --

	sql_tsp := 'select x, y, node_id from pgr_aStarTPP_radial_search_matrix order by id';
	
	For rec_astar in execute sql_tsp
					Loop
						--seq := seq +1 ;
						--gid := rec_astar.gid;
						--name := rec_astar.name;
						gid := rec_astar.node_id;
						RETURN NEXT;
					End Loop;
	
	/*
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
				sql_astar := 'SELECT gid, the_geom, name, pgr.cost, source, target,
						ST_Reverse(the_geom) AS flip_geom FROM ' ||
						'pgr_astar(''SELECT gid as id, source::integer, target::integer, '
						|| 'length::double precision AS cost, '
						|| 'x1::double precision, y1::double precision,'
						|| 'x2::double precision, y2::double precision,'
						|| 'reverse_cost::double precision FROM '
						|| quote_ident(tbl) || ''', '
						|| source_var || ', ' || target_var
						|| ' , true, true) as pgr, '
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
	*/

	-- Drop the temporary tables, otherwise the next time you will run the query it will show that the pgr_aStarTPP_radial_search_matrix, pgr_aStarTPP_radial_search_loop_nodes or pgr_aStarTPP_radial_search_matrix_sub table already exists --
	drop table pgr_aStarTPP_radial_search_loop_nodes;
	drop table pgr_aStarTPP_radial_search_matrix;
	drop table pgr_aStarTPP_radial_search_matrix_sub;
	return;
end;
$body$
language plpgsql volatile STRICT;


-- select gid from pgr_aStarTPP_radial_search_1_via_BESTSelection('ways', 28.93160, 40.99315,28.97078, 41.01387, 101)
-- Remove first and last row of results column as they represent start and end nodes. remaining are the best possible selections or our case.
