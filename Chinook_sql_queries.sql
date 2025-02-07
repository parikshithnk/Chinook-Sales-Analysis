-- objective questions  
-- 1. Does any table have missing values or duplicates? If yes how would you handle it?
select * from customer
where company is Null or address is null or city is null 
or state is null or country is null or postal_code is  null
or phone is null or email is null or support_rep_id is null;

-- 2. Find the top-selling tracks and top artist in the USA and identify their most famous genres
with topselling_track as (select track_id, sum(unit_price * quantity) as tot_sold_amt 
from invoice_line il join invoice i on il.invoice_id = i.invoice_id
where billing_country = 'USA'
group by track_id)

select t.name as track_name, tot_sold_amt, a.name as artisit_name, g.name as genre_name
from topselling_track tst join track t on t.track_id = tst.track_id
join album al on al.album_id = t.album_id
join artist a on a.artist_id = al.artist_id
join genre g on g.genre_id = t.genre_id
order by tot_sold_amt desc;

-- 3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
-- Age wise ditribution of employees in chinook
select age_bracket, count(employee_id) as no_of_employees 
from (select employee_id, 
case
	when timestampdiff(year, birthdate, now()) < 50 then "Under 50"
	when timestampdiff(year, birthdate, now()) between 50 and 60 then "50-60"
    when timestampdiff(year, birthdate, now()) between 60 and 70 then "60-70"
    when timestampdiff(year, birthdate, now()) > 70 then "Above 70"
end as age_bracket
from employee) as res
group by age_bracket
order by no_of_employees desc;

-- Location wise distribution of employees in chinook
select country, state, city, count(employee_id) as no_of_employees
from employee group by country, state, city
order by no_of_employees desc;

-- location wise distribution of customers in chinook
select country, count(customer_id) as no_of_customers 
from customer group by country order by no_of_customers desc;

-- 4. Calculate the total revenue and number of invoices for each country, state, and city:
-- Country wise revenue and number of invoices
select billing_country, sum(total) as tot_revenue, count(invoice_id) as no_of_invoices  
from invoice group by billing_country
order by tot_revenue desc;

-- State wise revenue and number of invoices
select billing_state, sum(total) as tot_revenue, count(invoice_id) as no_of_invoices  
from invoice 
where billing_state != 'None'
group by billing_state
order by tot_revenue desc;

-- City wise revenue and number of invoices
select billing_city, sum(total) as tot_revenue, count(invoice_id) as no_of_invoices  
from invoice group by billing_city
order by tot_revenue desc;

-- 5. Find the top 5 customers by total revenue in each country

with table1 as (select billing_country, customer_id, sum(total) as tot_revenue,
rank() over(partition by billing_country order by sum(total) desc) as rnk
from invoice group by billing_country, customer_id
order by billing_country, tot_revenue desc)

select t1.billing_country, concat(c.first_name,' ',c.last_name) as Customer_name, tot_revenue
from table1 t1 join customer c on c.customer_id = t1.customer_id
where rnk <= 5;

-- 6. Identify the top-selling track for each customer

select customer_id, track_id, unit_price, quantity
from invoice i join invoice_line il on il.invoice_id = i.invoice_id
order by customer_id, track_id;

-- 7. Are there any patterns or trends in customer purchasing behaviour 
-- (e.g., frequency of purchases, preferred payment methods, average order value)?

-- Customer patterns by avg order value per customer
with ord_value as (select customer_id, avg(total) as avg_ord_value
from invoice
group by customer_id
order by customer_id)

-- select * from ord_value;

select 
min(avg_ord_value) as Min_avg_ord_value,
max(avg_ord_value) as max_avg_ord_value,
avg(avg_ord_value) as overall_avg_ord_value
from ord_value;

-- Customers pattern by time of orders
with prev_date as (select 
customer_id,
invoice_date,
lag(invoice_date) over(partition by customer_id order by invoice_date) as previous_date
from invoice),

mpo as (select customer_id,
avg(coalesce(timestampdiff(month,previous_date, invoice_date),0)) as months_per_one_order
from prev_date
group by customer_id)
-- select * from mpo;
select avg(months_per_one_order) as overallmonths_per_one_order_by_eachcustomer from mpo;


-- 8. What is the customer churn rate?
-- Year on year churn rate:
with yearwisedata as (select extract(year from invoice_date) as Year,
count(distinct customer_id) as num_of_customers
from invoice
group by extract(year from invoice_date))

select *, 
(lag(num_of_customers) over(order by year) - num_of_customers) / 
(lag(num_of_customers) over(order by year)) * 100 as yearwise_Churn_rate
from yearwisedata;

-- 9. Calculate the percentage of total sales contributed by 
-- each genre in the USA and identify the best-selling genres and artists.

with usasales as (select * from invoice
where billing_country = 'USA'),

usa_genre_sales as (select g.name as genre_name, sum(il.unit_price * quantity) as tot_genre_sales
from usasales u join invoice_line il on il.invoice_id = u.invoice_id
join track t on t.track_id = il.track_id
join genre g on g.genre_id = t.genre_id
group by g.name)

select genre_name, 
(tot_genre_sales / (select sum(total) from invoice)) * 100 as 'contribution_to_tot_sales'
from usa_genre_sales
order by contribution_to_tot_sales desc;

-- top selling artists in UsA
select
ar.name as artist_name, 
a.title as album_name,
count(distinct t.track_id) as num_of_tracks,
sum(il.unit_price * il.quantity) as tot_amount_sold
from invoice i join invoice_line il on i.invoice_id = il.invoice_id
join track t on t.track_id = il.track_id
join album a on a.album_id = t.album_id
join artist ar on ar.artist_id = a.artist_id
where i.billing_country = 'USA'
group by ar.name, a.title
order by tot_amount_sold desc;

-- 10.	Find customers who have purchased tracks from at least 3 different genres
with custo_genre as (select concat(c.first_name,' ', c.last_name) as customer_name, t.genre_id
from customer c join invoice i on c.customer_id = i.customer_id
join invoice_line il on i.invoice_id = il.invoice_id
join track t on t.track_id = il.track_id)

select customer_name, count(distinct genre_id) as genre from custo_genre
group by customer_name having count(distinct genre_id) >= 3
order by genre desc; 

-- 11.	Rank genres based on their sales performance in the USA


with usasales as (select * from invoice
where billing_country = 'USA')

select g.name as genre_name, sum(il.unit_price * quantity) as tot_genre_sales
from usasales u join invoice_line il on il.invoice_id = u.invoice_id
join track t on t.track_id = il.track_id
join genre g on g.genre_id = t.genre_id
group by g.name
order by tot_genre_sales desc;

-- 12.	Identify customers who have not made a purchase in the last 3 months

select concat(first_name, ' ', last_name) as Customer_name
from customer
where customer_id NOT in (Select c.customer_id
from customer c join invoice i on c.customer_id = i.customer_id
where invoice_date >= 
date_add((select date(max(invoice_date)) from invoice), interval -3 month));

-- Subjective Questions

-- 1.Recommend the three albums from the new record label that 
-- should be prioritised for advertising and promotion in the USA 
-- based on genre sales analysis.

with usasales as (select * from invoice
where billing_country = 'USA')

select a.title as album_title, g.name as genre_name, sum(il.unit_price * quantity) as tot_genre_sales
from usasales u join invoice_line il on il.invoice_id = u.invoice_id
join track t on t.track_id = il.track_id
join genre g on g.genre_id = t.genre_id
join album a on a.album_id = t.album_id
group by a.title, g.name
order by genre_name, tot_genre_sales desc;


-- 2. Determine the top-selling genres in countries other than the USA 
-- and identify any commonalities or differences.

with non_usasales as (select * from invoice
where billing_country != 'USA')

select g.name as genre_name, sum(il.unit_price * quantity) as tot_genre_sales
from non_usasales u join invoice_line il on il.invoice_id = u.invoice_id
join track t on t.track_id = il.track_id
join genre g on g.genre_id = t.genre_id
group by g.name
order by tot_genre_sales desc;

-- 3. Customer Purchasing Behaviour Analysis: How do the purchasing habits 
-- (frequency, basket size, spending amount) of long-term customers differ from 
-- those of new customers? What insights can these patterns provide about customer loyalty 
-- and retention strategies?

with t1 as (select 
c.customer_id, 
invoice_id, 
invoice_date,
lag(invoice_date) over(partition by customer_id order by invoice_date) as prev_date,
total, sum(total) over(partition by customer_id) as tot_spending,
avg(total) over(partition by customer_id) as avg_per_invoice 
from customer c join invoice i on c.customer_id = i.customer_id
order by c.customer_id),

t2 as (select 
customer_id,
invoice_id,
timestampdiff(month,  prev_date, invoice_date) as TAT,
tot_spending,
avg_per_invoice
from t1),

t3 as (select 
customer_id,
count(invoice_id) as num_of_invoices,
avg(coalesce(TAT,0)) as avg_tat,
avg(tot_spending) as tot_spent,
avg(avg_per_invoice) as avg_per_invoice
from t2
group by customer_id
order by customer_id)

-- select * from t3;

-- Average tur around time for a customer
select avg(avg_tat) as Average_TAT from t3;

-- Average of total_spent by each customer
select avg(tot_spent) as Average_tot_spent from t3;

-- Average amount per invoice
select avg(avg_per_invoice) as average_price_per_invoice from t3;

-- Average num of invoices per customer
select avg(num_of_invoices) as numofinvoices_per_customer from t3;

-- 4. Product Affinity Analysis: Which music genres, artists, 
-- or albums are frequently purchased together by customers? 
-- How can this information guide product recommendations and cross-selling initiatives?

select
a.title as album_name , 
g.name as genre_name,
ar.name as artist_name,
count(distinct c.customer_id) as num_of_customers
from
customer c join invoice i on c.customer_id = i.customer_id
join invoice_line il on i.invoice_id = il.invoice_id
join track t on t.track_id = il.track_id
join genre g on g.genre_id = t.genre_id
join album a on a.album_id = t.album_id
join artist ar on ar.artist_id = a.artist_id
group by a.title, g.name, ar.name
order by num_of_customers desc;

-- 5. Regional Market Analysis: Do customer purchasing behaviours and churn rates 
-- vary across different geographic regions or store locations? 
-- How might these correlate with local demographic or economic factors?

-- Churn rate 
with t1 as (select billing_country, year(invoice_date) as year, 
count(distinct customer_id) as num_of_customers
from invoice group by billing_country, year(invoice_date)),

t2 as (select *,
lag(num_of_customers) over(partition by billing_country order by year) as prev_customers
from t1)

select billing_country,
avg(coalesce((prev_customers - num_of_customers) * 100 / prev_customers, 0)) as churn_rate
from t2 group by billing_country
order by churn_rate;

-- country wise purchasing behaviuor 

select billing_country, count(invoice_id) as num_of_invoices, sum(total) as tot_revenue 
from invoice
group by billing_country
order by tot_revenue desc;

-- 6. Customer Risk Profiling: Based on customer profiles 
-- (age, gender, location, purchase history), 
-- which customer segments are more likely to churn or 
-- pose a higher risk of reduced spending? What factors contribute to this risk?

with t1 as (select billing_country, year(invoice_date) as year, 
count(distinct customer_id) as num_of_customers
from invoice group by billing_country, year(invoice_date)),

t2 as (select *,
lag(num_of_customers) over(partition by billing_country order by year) as prev_customers
from t1)

select billing_country,
avg(coalesce((prev_customers - num_of_customers) * 100 / prev_customers, 0)) as churn_rate
from t2 group by billing_country
order by churn_rate;


-- 7. Chinook is interested in understanding the purchasing behavior of customers 
-- based on their geographical location. They want to know the average total amount spent by 
-- customers from each country, along with the number of customers and 
-- the average number of tracks purchased per customer. 
-- Write an SQL query to provide this information

select billing_country, 
sum(total) / count(distinct customer_id) as avg_amount_spent_by_customer,
count(distinct customer_id) as num_of_customers,
round(count(track_id) / count(distinct customer_id),0) as avg_tracks_per_customer
from invoice i join invoice_line il on i.invoice_id = il.invoice_id
group by billing_country
order by avg_amount_spent_by_customer desc;

-- Trend line of chinook sales over year:
select year(invoice_date) as Year, sum(total) as Tot_rev
from invoice
group by year(invoice_date)
order by year;



