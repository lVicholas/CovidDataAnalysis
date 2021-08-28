-- Some basic queries which may be of interest for further analysis

-- The dataset also includes entries for continents (such entries have location as 
-- continent name and continent as NULL),
-- so accessing countries requires 'WHERE continent IS NOT NULL'

-- Queries are generally in decreasing order of complexity

-------First create/update/clean some tables and views --------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

-- Update / clean tests_vaccinations table since some entries are NULL
-- NULL entries before vaccinations start are 0, others are latest non-NULL value
--
-- WITH cte1 AS (
--	SELECT location, date,
--	ISNULL(new_tests,0) nt,
--	COALESCE(total_tests,
--			 MAX(total_tests) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) tt,
--	COALESCE(people_fully_vaccinated,
--		     MAX(people_fully_vaccinated) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) pfv,
--	COALESCE(total_vaccinations,
--			 MAX(total_vaccinations) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) tv,
--	COALESCE(positive_rate,
--			 MAX(positive_rate) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) pr,
--	COALESCE(people_vaccinated,
--			 MAX(people_vaccinated) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),0) pv	
--	FROM tests_vaccinations
--),
--cte2 AS (
--	SELECT *,
--		   LEAD(tv,1) OVER (PARTITION BY location ORDER BY date DESC) new_nv
--	FROM cte1
--)
--UPDATE tests_vaccinations
--SET new_tests=cte2.nt,
--	total_tests=cte2.tt,
--	people_fully_vaccinated=cte2.pfv,
--	total_vaccinations=cte2.tv,
--	positive_rate=cte2.pr,
--	people_vaccinated=cte2.pv,
--	new_vaccinations=cte2.new_nv
--FROM tests_vaccinations tv INNER JOIN cte2 ON tv.location=cte2.location AND tv.date=cte2.date;

-- Create a view of country_totals (e.g. total deaths) as of 2021-08-20
-- CREATE VIEW present_country_totals AS
-- WITH cte AS (
--		SELECT cd.location, cd.continent,
--			   cd.population population,
--			   ISNULL(cd.total_cases,0) total_cases, 
--			   ISNULL(cd.total_deaths,0) total_deaths,
--			   ISNULL(tv.total_tests,0) total_tests, 
--			   ISNULL(tv.total_vaccinations,0) total_vaccinations,
--			   ISNULL(tv.people_fully_vaccinated,0) people_fully_vaccinated,
--			   100*ISNULL(tv.positive_rate,0) positive_rate
--		FROM cases_deaths cd
--			INNER JOIN tests_vaccinations tv 
--			ON cd.location=tv.location AND cd.date=tv.date
--		WHERE cd.continent IS NOT NULL AND cd.date='2021-08-20'
--	)
--	SELECT *,
--		   100*CASE WHEN total_cases=0 THEN 0 ELSE total_deaths/total_cases END fatality_rate,
--		   100*people_fully_vaccinated/population percent_population_vaccinated
--	FROM cte
--	ORDER BY total_cases DESC
-- OFFSET 0 ROWS;

--UPDATE cases_deaths
--SET total_cases=ISNULL(total_cases,0),
--	new_cases=ISNULL(new_cases,0),
--	total_deaths=ISNULL(total_deaths,0),
--	new_deaths=ISNULL(new_deaths,0);

-- Add country daily increase in vaccinated population (different than 'new_vaccinations') to table
--ALTER TABLE tests_vaccinations
--ADD newly_vaccinated_people FLOAT(53);
--WITH cte AS (
--	SELECT location, date,
--		   people_fully_vaccinated - 
--		   LEAD(people_fully_vaccinated,1) OVER (PARTITION BY location ORDER BY date DESC) var
--	FROM tests_vaccinations
--)
--UPDATE tests_vaccinations
--SET newly_vaccinated_people=cte.var
--FROM cte INNER JOIN tests_vaccinations tv
--ON cte.location=tv.location AND cte.date=tv.date;
--GO

---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

-- Get weekly vaccination rates (wrt population) for each country
WITH cte AS (
	SELECT tv.location, tv.population, DATEPART(week,tv.date) week,
		   tv.people_fully_vaccinated - 
		   LEAD(tv.people_fully_vaccinated,1) OVER (PARTITION BY tv.location ORDER BY tv.date DESC) newly_vaccinated_people
	FROM tests_vaccinations tv
	WHERE tv.continent IS NOT NULL
)
SELECT DISTINCT location, week,
	   ROUND(100*SUM(newly_vaccinated_people/population) OVER (PARTITION BY location,week),3) weekly_vaccination_rate
FROM cte
WHERE week BETWEEN 1 AND 29
ORDER BY location;

-- Get vaccination rates (wrt population) for each country between '2021-07-10' and '2021-07-17'
WITH cte AS (
	SELECT tv.location, tv.date, tv.population,
	   tv.people_fully_vaccinated - 
	   LEAD(tv.people_fully_vaccinated,1) OVER (PARTITION BY tv.location ORDER BY date DESC) AS people_newly_vaccinated
	FROM tests_vaccinations tv
	WHERE date BETWEEN '2021-07-10' and '2021-07-17' AND tv.continent IS NOT NULL
)
SELECT DISTINCT location, population,
	   ROUND(100*SUM(people_newly_vaccinated/cte.population) OVER (PARTITION BY cte.location),4) vaccination_rate
FROM cte
ORDER BY vaccination_rate DESC;
GO

-- Get vaccination rates of each country (wrt population) over week of '2021-07-10' -> '2021-07-17'
WITH cte AS (
	SELECT DISTINCT pct.location,
		   AVG(100*ISNULL(tv.new_vaccinations,0)/pct.population) vaccination_rate
	FROM present_country_totals pct
	INNER JOIN tests_vaccinations tv
	ON pct.location=tv.location AND tv.date BETWEEN '2021-07-10' AND '2021-07-17'
	GROUP BY pct.location, date
)
SELECT *
FROM cte
WHERE vaccination_rate IS NOT NULL;

-- Get number of newly vaccinated people every day per country
WITH cte AS (

	SELECT tv.location, tv.date, tv.people_fully_vaccinated, 
	   tv.people_fully_vaccinated - 
	   LEAD(tv.people_fully_vaccinated,1) OVER (PARTITION BY tv.location ORDER BY date DESC) AS people_newly_vaccinated
	FROM tests_vaccinations tv
	WHERE tv.continent IS NOT NULL

)
SELECT location, date, 
	   ISNULL(people_fully_vaccinated,0) people_fully_vaccinated,
	   ISNULL(people_newly_vaccinated,0) people_newly_vaccinated
FROM cte
ORDER BY location, date;


-- Getting percentages of people vaccinated per country
SELECT pct.location, pct.population, 
	   ROUND(100*ISNULL(tv.people_fully_vaccinated,0)/pct.population,4) percent_vaccinated
FROM present_country_totals pct
	INNER JOIN tests_vaccinations tv
	ON pct.location=tv.location AND tv.date='2021-07-17'
ORDER BY percent_vaccinated DESC;
GO

-- Get total population, cases, deaths, tests, vaccinations for each *continent* as of 2021-07-17
-- Also get totals as percentages of population
WITH cte AS (
	SELECT continent, 
		   SUM(population) population,
		   SUM(total_cases) total_cases, 
		   SUM(total_deaths) total_deaths,
		   SUM(total_tests) total_tests, 
		   SUM(total_vaccinations) total_vaccinations
	FROM present_country_totals
	GROUP BY continent
) 
SELECT *, 
       ROUND(100*cte.total_cases/cte.population,4) percent_cases,
	   ROUND(100*cte.total_deaths/cte.population,4) percent_deaths,
	   ROUND(100*cte.total_tests/cte.population,4) percent_tests,
	   ROUND(100*cte.total_vaccinations/cte.population,4) percent_vaccinations
FROM cte
ORDER BY continent;
GO

-- Calculate world totals directly from source tables
WITH cte AS (
	SELECT DISTINCT location, population 
	FROM cases_deaths
	WHERE cases_deaths.continent IS NOT NULL
)
SELECT 'World' World,
	   SUM(DISTINCT cte.population) total_population,
	   SUM(cd.new_cases) total_cases,
	   SUM(cd.new_deaths) total_deaths,
	   SUM(tv.new_tests) total_tests,
	   SUM(tv.new_vaccinations) total_vaccinations
FROM cases_deaths cd
	INNER JOIN tests_vaccinations tv
	ON cd.location=tv.location AND cd.date=tv.date
	INNER JOIN cte ON cd.location=cte.location
WHERE cd.continent IS NOT NULL;
GO

-- Get running fatality rates for each country
SELECT location, continent, date,
	   ISNULL(total_cases,0) total_cases,
	   ISNULL(total_deaths,0) total_deaths,
	   ISNULL(total_deaths/total_cases,0) fatality_percentage
FROM cases_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Get present_cases and present_deaths for each country
SELECT location, MAX(total_cases) total_cases, MAX(total_deaths) total_deaths
FROM cases_deaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY location;
GO

-- Equivalently,
SELECT DISTINCT location,
	   SUM(new_cases) OVER (PARTITION BY location) total_cases,
	   SUM(new_deaths) OVER (PARTITION BY location) total_deaths
FROM cases_deaths
WHERE continent IS NOT NULL
ORDER BY location;
GO

-- Calulcate running total of cases and deaths by day for each country
SELECT location, date, 
	   new_cases, 
	   SUM(new_cases) OVER (PARTITION BY location ORDER BY location, date) total_cases,
	   new_deaths,
	   SUM(new_deaths) OVER (PARTITION BY location ORDER BY location, date) total_deaths
FROM cases_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;
GO

-- Running total percentage of cases which are deaths per country by day
SELECT location, date, total_cases, total_deaths, 100*(total_deaths/total_cases) percent_deaths
FROM cases_deaths
WHERE total_deaths IS NOT NULL AND continent IS NOT NULL
ORDER BY location, date;
GO

-- Get global totals
SELECT 'World' World, SUM(population) population,
		SUM(total_cases) total_cases, SUM(total_deaths) total_deaths,
		SUM(total_tests) total_tests, SUM(total_vaccinations) total_vaccinations,
		SUM(people_fully_vaccinated) people_fully_vaccinated
FROM present_country_totals;
GO

-- Calculate percentage of world totals per country (e.g., what % of cases are from the US) using country_totals table
SELECT location, 
	   100*population/(SUM(population) OVER ()) global_percentage_population,
	   100*total_cases/(SUM(total_cases) OVER ()) global_percentage_cases,
	   100*total_deaths/(SUM(total_deaths) OVER ()) global_percentage_deaths,
	   100*total_tests/(SUM(total_tests) OVER ()) global_percentage_tests,
	   100*total_vaccinations/(SUM(total_vaccinations) OVER ()) global_percentage_vaccinations,
	   100*people_fully_vaccinated/(SUM(people_fully_vaccinated) OVER ()) global_percentage_population_vaccinated
FROM present_country_totals
ORDER BY global_percentage_population DESC, global_percentage_cases DESC;
GO

-- Calculate present ratio of totals to population for each country
-- This is not the same as percentage of population infected, since total_cases
-- includes people who were infected more than once
-- Also, tests and vaccinations may be greater than population, so percentages may be >=100%
SELECT location, population,
	   ROUND(100*total_cases/population,4) infection_percentage,
	   ROUND(100*total_deaths/population,4) death_percentage,
	   ROUND(100*total_tests/population,4) test_percentage,
	   ROUND(100*total_vaccinations/population,4) vaccination_percentage
FROM present_country_totals
ORDER BY location, infection_percentage DESC;
