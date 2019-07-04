
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetId_CheckVoidBetPermission] @TransIds VARCHAR(MAX) = NULL
	,@IsHostVoidSettledTickets BIT = 0
	,@IsHostVoidUnsettledTickets BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*  
	Created by: Raymond.Le  
	Date: 20190703
	Task: Check if user has permission to void bet in TransIds list
	DB: DBTXN/bodb02   
	Original:      

	Revisions:  
		- 20190703@Raymond.Le: Create new SP [Redmine: #115870]

	Param's Explanation:
		+ @TransIds
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsExistsSettledTickets BIT = 0
	DECLARE @transIdTemp TABLE (transid BIGINT PRIMARY KEY)

	INSERT INTO @TransIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	SELECT @IsExistsSettledTickets = CASE 
			WHEN EXISTS (
					SELECT TOP 1 1
					FROM @TransIdTemp AS t
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON t.transid = b.transid
					WHERE b.StatusId IN (111, 112, 113) -- 'DRAW', 'WON', 'LOSE'
					) THEN 1
			ELSE 0
			END

	IF (
			@IsExistsSettledTickets = 1
			AND @IsHostVoidSettledTickets = 0
			)
		OR (
			@IsHostVoidUnsettledTickets = 0
			AND @IsHostVoidSettledTickets = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'WARNING! Insufficient permission to void! You are about to back the page and try a new search.'

		RETURN
	END
END

