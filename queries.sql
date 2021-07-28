-- Some basic queries which may be of interest for further analysis

-- The dataset also includes entries for continents (such entries have location as 
-- continent name and continent as NULL),
-- so accessing countries requires 'WHERE continent IS NOT NULL'

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

-- First create a view of present_country_totals, since this query can be used elsewhere
-- Also, replace all NULL values with 0's, since we want this table to be of totals
CREATE VIEW present_country_totals AS
	SELECT cd.location, cd.continent,
		   AVG(cd.population) population,
		   ISNULL(MAX(cd.total_cases),0) total_cases, 
		   ISNULL(MAX(cd.total_deaths),0) total_deaths,
		   ISNULL(MAX(tv.total_tests),0) total_tests, 
		   ISNULL(MAX(tv.total_vaccinations),0) total_vaccinations
	FROM cases_deaths cd
		INNER JOIN tests_vaccinations tv 
		ON cd.location=tv.location AND cd.date=tv.date
	WHERE cd.continent IS NOT NULL
	GROUP BY cd.location, cd.continent
	ORDER BY total_cases DESC, total_deaths DESC
	OFFSET 0 ROWS;
GO
-- Gets total_cases, total_deaths for each country as of 2021-07-19
-- Note total_vaccinations counts shots (e.g. Pfizer has 2 shots per vaccine),
-- since many countries (e.g., US) have more vaccinations than populants

-- Also note any query which uses present_country_totals is equivalent to a similar query from
-- the source table(s) where the SELECT statement for present_country_totals defines a CTE

-- Get total population, cases, deaths, tests, vaccinations for each continent as of 2021-07-17
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

-- Create view for world totals
SELECT 'World' World, SUM(population) population,
		SUM(total_cases) total_cases, SUM(total_deaths) total_deaths,
		SUM(total_tests) total_tests, SUM(total_vaccinations) total_vaccinations
FROM present_country_totals;
GO

-- Can also calculate world totals directly from source tables
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

-- Calculate percentage of world totals per country (e.g., what % of cases are from the US) using country_totals table
SELECT location, 
	   ROUND(100*total_cases/(SUM(total_cases) OVER ()),4) global_percentage_cases,
	   ROUND(100*total_deaths/(SUM(total_deaths) OVER ()),4) global_percentage_deaths,
	   ROUND(100*total_tests/(SUM(total_tests) OVER ()),4) global_percentage_tests,
	   ROUND(100*total_vaccinations/(SUM(total_vaccinations) OVER ()),4) global_percentage_vaccinations
FROM present_country_totals
ORDER BY global_percentage_cases DESC, global_percentage_deaths DESC;
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
ORDER BY infection_percentage DESC, death_percentage DESC;

-- Getting percentages of people vaccinated per country
SELECT pct.location, ROUND(100*tv.people_fully_vaccinated/pct.population,4) percent_vaccinated
FROM present_country_totals pct
	INNER JOIN tests_vaccinations tv
	ON pct.location=tv.location AND tv.date='2021-07-17'
ORDER BY percent_vaccinated DESC;

-- Get vaccination rates of each country (wrt population) over week of '2021-07-10' -> '2021-07-17'
SELECT pct.location,
	   AVG(100*tv.new_vaccinations/pct.population) vaccination_rate
FROM present_country_totals pct
INNER JOIN tests_vaccinations tv
ON pct.location=tv.location AND tv.date BETWEEN '2021-07-10' AND '2021-07-17'
GROUP BY pct.location
ORDER BY vaccination_rate DESC;
