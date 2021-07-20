-- Some basic queries which may be of interest for further analysis

-- Calulcate running cases and deaths
-- Can acheive same thing by using total_cases, total_deaths in cases_deaths
SELECT location, date, new_cases, 
	   SUM(new_cases) OVER (PARTITION BY location ORDER BY location, date) total_cases,
	   new_deaths,
	   SUM(new_deaths) OVER (PARTITION BY location ORDER BY location, date) total_deaths
FROM cases_deaths
ORDER BY location, date;
GO

-- Running total percentage of cases --> deaths per country by day
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100
FROM cases_deaths
ORDER BY location, date;
GO

-- Get total_cases, total_deaths for each country as of 19/07/2021
-- Note total_vaccinations counts shots (e.g. Pfizer has 2 shots per vaccine)
SELECT cd.location, AVG(cd.population) population,
	   MAX(cd.total_cases) total_cases, MAX(cd.total_deaths) total_deaths,
	   MAX(tv.total_tests) total_tests, MAX(tv.total_vaccinations) total_vaccinations
FROM cases_deaths cd
	INNER JOIN tests_vaccinations tv 
	ON cd.location=tv.location AND cd.date=tv.date
WHERE cd.continent IS NOT NULL
GROUP BY cd.location
ORDER BY total_cases DESC, total_deaths DESC;
GO

-- Get total cases, deaths, tests, vaccinations for each continent as of 19/07/2021
SELECT cd.location, AVG(cd.population) population,
	   MAX(cd.total_cases) total_cases, MAX(cd.total_deaths) total_deaths,
	   MAX(tv.total_tests) total_tests, MAX(tv.total_vaccinations) total_vaccinations
FROM cases_deaths cd
INNER JOIN tests_vaccinations tv
	ON cd.location=tv.location AND cd.date=tv.date
WHERE cd.continent IS NULL
GROUP BY cd.location
ORDER BY population DESC, total_cases DESC, total_deaths DESC;
-- In the above table, we see tests column is NULL b/c some countries never reported tests

-- First create table with totals for each location
--IF NOT EXISTS (SELECT * FROM sysobjects WHERE NAME='present_totals' AND XTYPE='U')
--	SELECT cd.location, cd.continent, MAX(cd.population) population, MAX(cd.total_cases) total_cases, MAX(cd.total_deaths) total_deaths,
--			MAX(tv.total_tests) total_tests, MAX(tv.total_vaccinations) total_vaccinations
--	INTO present_totals
--	FROM cases_deaths cd INNER JOIN tests_vaccinations tv
--						ON cd.location=tv.location AND 
--						cd.date=tv.date
--	GROUP BY cd.location, cd.continent
--	ORDER BY population DESC, total_cases DESC, total_deaths DESC;
--GO

-- Query for totals table
--SELECT cd.location, cd.continent, MAX(cd.population) population, MAX(cd.total_cases) total_cases, MAX(cd.total_deaths) total_deaths,
--			MAX(tv.total_tests) total_tests, MAX(tv.total_vaccinations) total_vaccinations
--FROM cases_deaths cd INNER JOIN tests_vaccinations tv
--						ON cd.location=tv.location AND 
--						cd.date=tv.date
--	GROUP BY cd.location, cd.continent
--	ORDER BY population DESC, total_cases DESC, total_deaths DESC;
