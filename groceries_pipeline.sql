-- step 1: create s3 bucket
-- step 2: create IAM user
-- step 3: create file format that supports your data (here we use existing format)
create or replace file format my_csv_fileformat
    type = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

SHOW file formats;

-- step 4: create a stage to access the s3 files : External stages

create or replace stage s3_external_sage
    URL = 's3-bucket-URI'
    CREDENTIALS = (
        AWS_KEY_ID = 'your-aws-key-id'
        AWS_SECRET_KEY = 'your-aws-secret-key'
    )
    FILE_FORMAT = my_csv_fileformat;

    list @s3_external_sage;


-- step 5: create tables that fit data

create or replace table categories(
    categoryId int,
    categoryName string
);
drop table categories;

-- use external table
create or replace external table categories(
    categoryId int as (value:C1::number), --mentioning the column1 convert it into number
     categoryName string as (value:C2::string)
)
LOCATION = @s3_external_sage/categories1/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat');

select * from categories;

  list @s3_external_sage;
-- ----------------------------
create or replace external table categories(
    categoryId int as (value:C1::number), --mentioning the column1 convert it into number
     categoryName string as (value:C2::string)
)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*categorie[.]csv';


-- TABELE 2 : products
create or replace external table products(
    ProductID int as (value:c1::number) ,
    ProductName string as (value:c2::string),
    Price	float as (value:c3::float),
    CategoryID	int as (value:c4::number),
    Class string as (value:c5::string),	
    ModifyDate date as (value:c6::date),
    Resistant string as (value:c7::string),
    IsAllergic string as (value:c8::string),
    VitalityDays int as (value:c9::number)

)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*products[.]csv';

select * from products;


-- table 3 : city
create or replace external table cities(
    cityId int as (value:c1::number), --mentioning the column1 convert it into number
     cityName string as (value:c2::string),
     zipcode int as (value:c3::number),
     countryID int as (value:c4::number)
)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*cities[.]csv';

select * from cities; 

-- table 4: employees
create or replace external table employees(
    EmployeeID int as (value:c1::number),
    FirstName string as (value:c2::string),
    MiddleInitial varchar(2) as (value:c3::varchar),
    LastName string as (value:c4::string),	
    BirthDate timestamp as (value:c5::timestamp),
    Gender varchar(2) as (value:c6::varchar),
    CityID	int as (value:c7::number),
    HireDate timestamp as (value:c8::timestamp)
)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*employees[.]csv';

select * from employees;
show tables;
-- table 5: customers
create or replace external table customers1(
    CustomerID int as (value:c1::number),
    FirstName string as (value:c2::string),
    MiddleInitial varchar(2) as (value:c3::varchar),
    LastName string as (value:c4::string),
    CityID int as (value:c5::number),
    Address string as (value:c6::string)

)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*customers[.]csv';

select * from customers1 limit 5;


-- table 6 : countries

create or replace external table countries(
    CountryID int as (value:c1::number),
    CountryName	string as (value:c2::string),
    CountryCode varchar(2) as (value:c3::varchar)

)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*countries[.]csv';

select * from countries; 

-- table 7 : sales
create or replace external table sales(
    SalesID	int as (value:c1::number),
    SalesPersonID int as (value:c2::number),
    CustomerID int as (value:c3::number),
    ProductID int as (value:c4::number),
    Quantity int as (value:c5::number),
    Discount float as (value:c6::float),
    TotalPrice	int as (value:c7::number),
    SalesDate timestamp as (value:c8::timestamp),
    TransactionNumber string as (value:c9::string)

)
LOCATION = @s3_external_sage/
FILE_FORMAT = (FORMAT_NAME='my_csv_fileformat')
PATTERN = '.*sales[.]csv';

select * from sales limit 5; 

-- check table is external or not
select table_name,table_type from information_schema.tables;
select table_name,table_type from information_schema.tables where table_name='CITIES';


-- next step : clean your data
-- check for null, case mismatch ,
-- transform customerss and add new column containing full name
-- emplyees : hire month,hired year, hired day 
-- products : change decimal point to 2 positions
-- sales : update total price , find price in product table * quantity (apply discount if there is)
-- 

-- category ok
-- products : set decimal to 2 decimal
-- alter table products modify price decimal(10,2); cantr chnage dirctly from float to number(10,2)
update products set price = round(price,2);
select * from products;


-- updating customers to add full name
alter table customers1 add column fullname varchar(100);

create view customersView as select *, concat_ws(' ',FirstName,MiddleInitial,lastname) as fullname from customers1;
select * from customersView;


-- employee table : add fullname, hire month ,year and day
drop view employeeview;
create view employeeView as 
select *,concat_ws(' ',FirstName,MiddleInitial,lastname) as fullname,year(hiredate) as hiredYear,month(hiredate) as hiredMonth,day(hiredate) as hiredDay from employees;
select * from employeeView;

-- product table : price to 2 decimal points
create view productsview as select *,round(price,2) as RoundedPrice from products;
select * from productsview limit 10;



-- sales : update total price , find price in product table * quantity (apply discount if there is)
select * from sales limit 14;

 select  s.salesid,s.SalesPersonID,s.CustomerID,s.ProductID,s.Quantity,s.Discount,s.SalesDate,s.TransactionNumber,p.roundedprice,
    s.quantity*p.roundedprice - (s.discount * p.roundedprice) as newTotalPrice
    from sales s join productsview p on s.productid = p.productid  limit 15;

create view salesdataView as 
    select  s.salesid,s.SalesPersonID,s.CustomerID,s.ProductID,s.Quantity,s.Discount,s.SalesDate,s.TransactionNumber,p.roundedprice,
    s.quantity*p.roundedprice - (s.discount * p.roundedprice) as newTotalPrice
    from sales s join productsview p on s.productid = p.productid ;
select * from salesdataview limit 10;


-- KPI (Key Performance Indicators) : includes overall table
-- fact table : main table
-- dimension table : connecting tables

-- total sales 
select count(*) from salesdataview;
-- total revenue
select sum(newtotalprice) as revenue from salesdataview;
-- avg revenue
select round(avg(newtotalprice),2) from salesdataview;
-- total qty sold
select sum(quantity) from salesdataview;
-- total unique customers
select count(distinct(customerid)) from salesdataview; 
-- avg order value = tot revenue/total no of orders placed
select sum(newtotalprice)/count(*) as AverageOrderValue from salesdataview;




-- find insights from data
-- ============================
-- 1. top performing products
-- 2. valuable customers
-- 3. which cites generates more revenue

-- 1. top performing products
