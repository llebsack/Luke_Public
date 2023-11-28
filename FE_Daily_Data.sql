-- This is an example stored procedure used in SQL Server

USE [FE7Database]
GO

/****** Object:  StoredProcedure [dbo].[FE_Daily_Data]    Script Date: 11/28/2023 9:20:20 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- Authors: Luke Lebsack
-- Create date: 10/14/2023
-- Description:	This procedure is run daily to upload the essential Financial Edge data (accounting data) and put it into a transaction table. 
--               FE_Daily_Transactions is used for reporting and auditing purposes. 
-- Source Tables:		
--	gl7transactions				
--	gl7accounts				
--	gl7transactiondistributions				
--	gl7projects
--  
-- Destination Tables:	
--  FE_Daily_Transactions
--  FE_log 
--						
-- Parameters:	@startrange (DATETIME) defaults to NULL. The starting day of the date range 
--					the proc will calculate.
--				@endrange (DATETIME) defaults to NULL. The ending day of the date range the 
--					proc will calculate. If @startrange = @endrange, the proc will calculate 
--					for 1 day.
-- Modifications: <Date> <Author> <Description>

CREATE PROCEDURE [dbo].[FE_Daily_Data]
	 @startrange DATETIME = NULL
	,@endrange DATETIME = NULL 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON
	--set ansi_warnings on 
	SET ANSI_NULLS ON

	DECLARE  @start_date	VARCHAR(8)
			,@jobnum		INT
			,@startofday	DATETIME
			,@endofday		DATETIME
			,@currentday	DATETIME
			,@rangeresult	VARCHAR(500)
			,@stepresult	INT
			,@rangedeleted	INT


	---------------------------------------------------------------------------------------------------------------------------------
	-- Tracking the job by grabbing the next run number
	---------------------------------------------------------------------------------------------------------------------------------
	SELECT @jobnum = ISNULL(max(jobnum), 0) + 1
	FROM FE_log

 
	---------------------------------------------------------------------------------------------------------------------------------
	-- STEP 0
	-- SETTING THE RANGE
	---------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------
	-- DATE RANGE OF RUN
	-- changes NULL dates to yesterday, if both are null
	-- if its just a NULL start, we use the end date
	-- if its just a NULL end, we go from start to yesterday.
	-- if start > end, it won't make it into the loop and process nothing
	---------------------------------------------------------------------------------------------------------------------------------
	SET @rangeresult = 'Setting the dates based on input parameters. The start day parameter was '

	IF (@startrange IS NULL) AND (@endrange IS NULL )
	BEGIN
		SET @startrange = DATEADD(DAY, DATEDIFF(DAY, 0, (GETDATE() - 1)), 0)
		SET @endrange = DATEADD(SECOND, - 1, (DATEADD(DAY, DATEDIFF(DAY, 0, (GETDATE() - 1)), + 1)))
		SET @rangeresult = @rangeresult + 'NULL and the end day parameter was NULL.'
	END
	ELSE IF (@startrange IS NULL) 
	BEGIN
		SET @startrange = @endrange
		SET @rangeresult = @rangeresult + 'NULL and the end day parameter was ' + CONVERT(VARCHAR(20), @endrange, 120) + '.'
	END
	ELSE IF (@endrange IS NULL) 
	BEGIN
		SET @endrange = DATEADD(SECOND, - 1, (DATEADD(DAY, DATEDIFF(DAY, 0, (GETDATE() - 1)), + 1)))
		SET @rangeresult = @rangeresult + CONVERT(VARCHAR(20), @startrange, 120) + ' and the end day parameter was NULL.'
	END
	ELSE
	BEGIN
		SET @rangeresult = @rangeresult + CONVERT(VARCHAR(20), @startrange, 120) + 'and the end day parameter was ' + CONVERT(VARCHAR(20), @endrange, 120) + '.'
	END

	--Tracking job step 0
	INSERT INTO FE_log (JobNum, stepruntime, startday, endday, runday, jobstep, result)
	VALUES (@jobnum, GETDATE(), @startrange, @endrange, @currentday, 0, @rangeresult)
	---------------------------------------------------------------------------------------------------------------------------------
	-- END Date range build
	---------------------------------------------------------------------------------------------------------------------------------

	---------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	-- STEP 1
	-- DELETING CURRENT DATA FOR THE CURRENT DAY
	--
	--To avoid duplication of data, the procedure will delete the current data in the table, for the days that it is currently running.
	---------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------------
	
	BEGIN 
		SELECT * 
		FROM FE_Daily_Transactions
		WHERE FE_Daily_Transactions.postdate
		BETWEEN @startrange AND @endrange

		SET @stepresult = @@ROWCOUNT
	END

	IF (@stepresult > 0)
	BEGIN TRY
		DELETE 
		FROM FE_Daily_Transactions
		WHERE FE_Daily_Transactions.postdate
		BETWEEN @startrange AND @endrange

		----**Tracking job step 1
		INSERT INTO FE_log (JobNum, stepruntime, startday, endday, runday, jobstep, result)
				VALUES (
				@jobnum
				, GETDATE()
				, @startrange
				, @endrange, @currentday, 9
				, 'Deleted data from ' + @start_date + '. Rows deleted: ' + CONVERT(VARCHAR(10)
				, isnull(@stepresult,'0'))
				)
	END TRY

	----**Tracking job step 2 for if no data was in the current table------------------------------------------------------------------------------------------------------------

	BEGIN CATCH
		--ERROR Track
		INSERT INTO FE_log (
			JobNum
			,stepruntime
			,startday
			,endday
			,runday
			,jobstep
			,result
			)
		VALUES (
			@jobnum
			,GETDATE()
			,@startrange
			,@endrange
			,@currentday
			,- 1
			,'ERROR #:' + CONVERT(VARCHAR(10), ERROR_NUMBER()) + ' Severity: ' + CONVERT(VARCHAR(10), ERROR_SEVERITY()) + ' State: ' + CONVERT(VARCHAR(10), ERROR_STATE()) + ' Procedure: ' + ERROR_PROCEDURE() + ' Line #: ' + CONVERT(VARCHAR(10), ERROR_LINE()) + ' Message: ' + ERROR_MESSAGE()
			)
	END CATCH
	
	-------------------------------------------------------------------------------------------------------------------------------
	-- END Delete current day
	---------------------------------------------------------------------------------------------------------------------------------


	---------------------------------------------------------------------------------------------------------------------------------
	-- STEP 2 Loop through each day in the range
	---------------------------------------------------------------------------------------------------------------------------------
	
	SET @currentday = @startrange

	BEGIN TRY
		WHILE @currentday <= @endrange
		BEGIN
			SET @start_date = (convert(VARCHAR(8), @currentday, 112))

			SELECT
				accountnumber
				,b.description AS account_description
				,projectid
				,d.description AS project_description
				,convert(VARCHAR(8), a.[postdate], 112) AS Post_Date
				,a.postdate
				,CASE 
					WHEN transactiontype = 2
						THEN 'C'
					ELSE 'D'
					END AS TRANSACTIONTYPE -- transaction category does not represent all possible categories as currently constructed
				,CASE 
					WHEN transactiontype = 2
						THEN - a.amount
					ELSE a.amount
					END AS AMOUNT
				,reference
				,journal
				,reversedate
				,reversedtransactionsid
				,transactionnumber
				,a.addedbyid
				,a.dateadded
				,a.lastchangedbyid
				,a.datechanged
				,a.importid
				,copiedfromid
				,taxentityid
			INTO #FE_Daily_Transactions_temp
			FROM [dbo].[gl7transactions] a
			LEFT JOIN [dbo].[gl7accounts] b ON a.gl7accountsid = b.gl7accountsid
			LEFT JOIN [dbo].[gl7transactiondistributions] c ON a.[gl7transactionsid] = c.[gl7transactionsid]
			LEFT JOIN [dbo].[gl7projects] d ON d.[gl7projectsid] = c.[gl7projectsid]
			WHERE projectid IS NOT NULL
				AND a.postdate BETWEEN @startrange
					AND @endrange
		END	

		INSERT INTO FE_Daily_Transactions
		SELECT *
		FROM #FE_Daily_Transactions_temp a

	END TRY

	----**Tracking job step 3 for if if there was an error------------------------------------------------------------------------------------------------------------
	BEGIN CATCH
		--ERROR Track
		INSERT INTO FE_log (
			JobNum
			,stepruntime
			,startday
			,endday
			,runday
			,jobstep
			,result
			)
		VALUES (
			@jobnum
			,GETDATE()
			,@startrange
			,@endrange
			,@currentday
			,- 1
			,'ERROR #:' + CONVERT(VARCHAR(10), ERROR_NUMBER()) + ' Severity: ' + CONVERT(VARCHAR(10), ERROR_SEVERITY()) + ' State: ' + CONVERT(VARCHAR(10), ERROR_STATE()) + ' Procedure: ' + ERROR_PROCEDURE() + ' Line #: ' + CONVERT(VARCHAR(10), ERROR_LINE()) + ' Message: ' + ERROR_MESSAGE()
			)
	END CATCH

	DROP TABLE #FE_Daily_Transactions_temp
END

GO


