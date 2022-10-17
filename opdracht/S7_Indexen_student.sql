-- ------------------------------------------------------------------------
-- Data & Persistency
-- Opdracht S7: Indexen
--
-- (c) 2020 Hogeschool Utrecht
-- Tijmen Muller (tijmen.muller@hu.nl)
-- André Donk (andre.donk@hu.nl)
-- ------------------------------------------------------------------------
-- LET OP, zoals in de opdracht op Canvas ook gezegd kun je informatie over
-- het query plan vinden op: https://www.postgresql.org/docs/current/using-explain.html


-- S7.1.
--
-- Je maakt alle opdrachten in de 'sales' database die je hebt aangemaakt en gevuld met
-- de aangeleverde data (zie de opdracht op Canvas).
--
-- Voer het voorbeeld uit wat in de les behandeld is:
-- 1. Voer het volgende EXPLAIN statement uit:
--    EXPLAIN SELECT * FROM order_lines WHERE stock_item_id = 9;
--    Bekijk of je het resultaat begrijpt. Kopieer het explain plan onderaan de opdracht

-- "Gather  (cost=1000.00..6151.77 rows=1005 width=97)"
-- "  Workers Planned: 2"
-- "  ->  Parallel Seq Scan on order_lines  (cost=0.00..5051.27 rows=419 width=97)"
-- "        Filter: (stock_item_id = 9)"

-- 2. Voeg een index op stock_item_id toe:
--    CREATE INDEX ord_lines_si_id_idx ON order_lines (stock_item_id);
-- 3. Analyseer opnieuw met EXPLAIN hoe de query nu uitgevoerd wordt
--    Kopieer het explain plan onderaan de opdracht

-- "Bitmap Heap Scan on order_lines  (cost=12.08..2298.41 rows=1005 width=97)"
-- "  Recheck Cond: (stock_item_id = 9)"
-- "  ->  Bitmap Index Scan on ord_lines_si_id_idx  (cost=0.00..11.83 rows=1005 width=0)"
-- "        Index Cond: (stock_item_id = 9)"

-- 4. Verklaar de verschillen. Schrijf deze hieronder op.
-- met de index toegevoegd hoeft de database niet eerst alles te verzamellen en daar dan de scan op uit te voeren
-- het kan gelijk naar de indexen kijken waar stock_item_id = 9

-- S7.2.
--
-- 1. Maak de volgende twee query’s:
-- 	  A. Toon uit de order tabel de order met order_id = 73590
SELECT * FROM orders
WHERE order_id = 73590;

-- 	  B. Toon uit de order tabel de order met customer_id = 1028
SELECT * FROM orders
WHERE customer_id = 1028;

-- 2. Analyseer met EXPLAIN hoe de query’s uitgevoerd worden en kopieer het explain plan onderaan de opdracht

EXPLAIN SELECT * FROM orders WHERE order_id = 73590;
-- "Index Scan using pk_sales_orders on orders  (cost=0.29..8.31 rows=1 width=155)"
-- "  Index Cond: (order_id = 73590)"

EXPLAIN Select * from orders where customer_id = 1028;
-- "Seq Scan on orders  (cost=0.00..1819.94 rows=107 width=155)"
-- "  Filter: (customer_id = 1028)"

-- 3. Verklaar de verschillen en schrijf deze op
-- bij het zoeken op order_id gebruikt de query de constraint 'pk_sales_orders' bij het scannen op de tabel orders
-- bij het zoeken op customer_id zoekt de query gelijk op de tabel orders

-- 4. Voeg een index toe, waarmee query B versneld kan worden
CREATE INDEX ord_customer_id ON orders (customer_id);
-- 5. Analyseer met EXPLAIN en kopieer het explain plan onder de opdracht
EXPLAIN Select * from orders where customer_id = 1028;
-- "Bitmap Heap Scan on orders  (cost=5.12..308.96 rows=107 width=155)"
-- "  Recheck Cond: (customer_id = 1028)"
-- "  ->  Bitmap Index Scan on ord_customer_id  (cost=0.00..5.10 rows=107 width=0)"
-- "        Index Cond: (customer_id = 1028)"

-- 6. Verklaar de verschillen en schrijf hieronder op
-- nu gebruikt de query de index ord_customer_id waardoor de cost lager is

-- S7.3.A
--
-- Het blijkt dat customers regelmatig klagen over trage bezorging van hun bestelling.
-- Het idee is dat verkopers misschien te lang wachten met het invoeren van de bestelling in het systeem.
-- Daar willen we meer inzicht in krijgen.
-- We willen alle orders (order_id, order_date, salesperson_person_id (als verkoper),
--    het verschil tussen expected_delivery_date en order_date (als levertijd),
--    en de bestelde hoeveelheid van een product zien (quantity uit order_lines).
-- Dit willen we alleen zien voor een bestelde hoeveelheid van een product > 250
--   (we zijn nl. als eerste geïnteresseerd in grote aantallen want daar lijkt het vaker mis te gaan)
-- En verder willen we ons focussen op verkopers wiens bestellingen er gemiddeld langer over doen.
-- De meeste bestellingen kunnen binnen een dag bezorgd worden, sommige binnen 2-3 dagen.
-- Het hele bestelproces is er op gericht dat de gemiddelde bestelling binnen 1.45 dagen kan worden bezorgd.
-- We willen in onze query dan ook alleen de verkopers zien wiens gemiddelde levertijd
--  (expected_delivery_date - order_date) over al zijn/haar bestellingen groter is dan 1.45 dagen.
-- Maak om dit te bereiken een subquery in je WHERE clause.
-- Sorteer het resultaat van de hele geheel op levertijd (desc) en verkoper.
-- 1. Maak hieronder deze query (als je het goed doet zouden er 377 rijen uit moeten komen, en het kan best even duren...)
Select o.order_id, o.order_date, o.salesperson_person_id as verkoper, AGE(expected_delivery_date, order_date) AS levertijd, quantity
from orders o
join order_lines l
on l.order_id = o.order_id
where quantity > 250 and o.order_id in (select order_id
                                        from orders
                                        where (expected_delivery_date - order_date) > 1.45)
order by verkoper, levertijd desc;

-- S7.3.B
--
-- 1. Vraag het EXPLAIN plan op van je query (kopieer hier, onder de opdracht)
-- "Gather Merge  (cost=7666.40..7698.60 rows=276 width=32)"
-- "  Workers Planned: 2"
-- "  ->  Sort  (cost=6666.38..6666.72 rows=138 width=32)"
-- "        Sort Key: o.salesperson_person_id, (age((o.expected_delivery_date)::timestamp with time zone, (o.order_date)::timestamp with time zone)) DESC"
-- "        ->  Nested Loop  (cost=0.58..6661.47 rows=138 width=32)"
-- "              Join Filter: (l.order_id = o.order_id)"
-- "              ->  Nested Loop  (cost=0.29..6591.11 rows=138 width=12)"
-- "                    ->  Parallel Seq Scan on order_lines l  (cost=0.00..5051.27 rows=415 width=8)"
-- "                          Filter: (quantity > 250)"
-- "                    ->  Index Scan using pk_sales_orders on orders  (cost=0.29..3.71 rows=1 width=4)"
-- "                          Index Cond: (order_id = l.order_id)"
-- "                          Filter: (((expected_delivery_date - order_date))::numeric > 1.45)"
-- "              ->  Index Scan using pk_sales_orders on orders o  (cost=0.29..0.49 rows=1 width=16)"
-- "                    Index Cond: (order_id = orders.order_id)"

-- 2. Kijk of je met 1 of meer indexen de query zou kunnen versnellen
-- kan ik niet vinden

-- 3. Maak de index(en) aan en run nogmaals het EXPLAIN plan (kopieer weer onder de opdracht)
-- 4. Wat voor verschillen zie je? Verklaar hieronder.



-- S7.3.C
--
-- Zou je de query ook heel anders kunnen schrijven om hem te versnellen?
-- waarscijnlijk als je ook de subquery via indexen laat werken dat het dan sneller zal zijn


