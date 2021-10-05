/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_ConversationPick @FunctionName varchar(200)
	, @ContractName	varchar(200)	
	, @ConversationHandle uniqueidentifier output

as
/*  Created: Patrick@20210801
	Task: Pick conversation
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin 
	set nocount on 

	declare @__conversationNo int, @__cnt int
			  
	select @__cnt = Cnt
	from sb.ConversationCount with (nolock)
	where FunctionName = @FunctionName and ContractName = @ContractName
	
	set @__cnt = ISNULL(@__cnt, 0)
	
	if @__cnt = 0
	begin
		set @ConversationHandle = NULL
		return
	end
	
	set @__conversationNo = rand() * @__cnt + 1
	
	select @ConversationHandle = ConversationHandle
	from sb.ConversationManagement with(nolock)
	where FunctionName = @FunctionName
			and contractName = @ContractName
			and ConversationNo = @__conversationNo 
			and IsValid = 1
end
go