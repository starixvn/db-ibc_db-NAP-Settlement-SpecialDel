/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_s164_Validation_Event
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10) 
	,@ErrCode		INT		 = 0		OUTPUT
	,@ErrMsg		NVARCHAR(300)  = '' OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: initial [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, REFUND		

		@SelectedResources: 
			happy5:
				'<Resources>
						<Resource Id="1" Result="1" /><Resource Id="2" Result="2" /><Resource Id="3" Result="3" /><Resource Id="4" Result="4" /><Resource Id="5" Result="5" />
				</Resources>'	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount INT

	--invalid ball
	IF @Action LIKE 'CAL%'
	BEGIN
		DECLARE @tmpResultDetail TABLE (ResourceID VARCHAR(20), Result VARCHAR(50))
		
		INSERT INTO @tmpResultDetail(ResourceID, Result)
		SELECT  Seq, Number
		FROM	dbo.BingoBall b WITH (NOLOCK)
		WHERE matchid = @matchid

		SET @RowCount = @@ROWCOUNT
	
		IF @RowCount = 0
		BEGIN
			SELECT	@ErrCode = 1000001
					,@ErrMsg	= 'Ball number is required.'

			RETURN
		END
		
		IF @RowCount <> 5
		BEGIN
			SELECT	@ErrCode = 1000002
					,@ErrMsg = 'Data is not valid'

			RETURN
		END 

		SELECT	@ErrCode = 1000002
				,@ErrMsg = 'Duplicate ball numbers'
		FROM	@tmpResultDetail
		GROUP BY Result
		HAVING COUNT(Result) > 1
			
		SELECT	@ErrCode = 1000002
				,@ErrMsg = 'Ball number must be from 1 to 20'
		FROM	@tmpResultDetail
		WHERE Result NOT BETWEEN 1 AND 20
		
		IF @ErrCode <> 0
			RETURN
	END
END
GO