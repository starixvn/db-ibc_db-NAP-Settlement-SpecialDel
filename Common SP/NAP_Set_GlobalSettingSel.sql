/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_GlobalSettingSel]
	@LockName VARCHAR(100)
	,@ThreadHold INT = 0 OUTPUT
AS

/*
    Created: 20210514@Kathy
    Task: 
    DB: DBTXN/bodb02
    Revisions:       
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
   
    Parameters Explanation:        
    
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpGlobalSetting TABLE (LockName VARCHAR(100) PRIMARY KEY, ThreadHold INT)
	
	INSERT INTO @tmpGlobalSetting(LockName, ThreadHold)
	VALUES ('ParlayRefno', 10000)

	SET @ThreadHold = 0

	SELECT	@ThreadHold = ThreadHold
	FROM	@tmpGlobalSetting
	WHERE	LockName = @LockName
END
GO