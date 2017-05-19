ALTER PROCEDURE [dbo].[Nap_Admin_Settlement_s213_Job]
AS
	/* 
		Create: Johnson
		Date: 2016-08-24
		Task: settlement job for NG2
		DB: DBTXN/bodb02
		
		Revision:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @task VARCHAR(50)
	
	IF EXISTS (SELECT TOP 1 1 FROM settlementNG2_message WITH(NOLOCK) WHERE status = 'Calculating')
		RETURN;
		
	SELECT TOP (1) @task = task 
	FROM settlementNG2_message WITH(NOLOCK)
	WHERE status = 'copied'
	ORDER BY seqID ASC
	
	IF @@ROWCOUNT = 0 RETURN;
	
	IF @task = 'Settlement'
		EXEC NAP_Admin_Settlement_s213
	ELSE IF @task = 'Refund'
		EXEC NAP_Admin_Settlement_Refund_s213
END
