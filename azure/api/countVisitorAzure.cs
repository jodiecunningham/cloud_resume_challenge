using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Azure.Data.Tables;

namespace Jodie.CloudResumeChallenge
{
    public static class countVisitorAzure
    {
        [FunctionName("countVisitorAzure")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "countVisitor")] HttpRequest req,
            ILogger log)
        {
            string partitionKey = "Azure";
            string rowKey = "A1";
            var defaultRow = new TableEntity(partitionKey, rowKey) {
                {"VisitCounter",0}
            };
            log.LogInformation("C# HTTP trigger function processed a request.");

            TableServiceClient tableServiceClient = new TableServiceClient(Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING"));

            // New instance of TableClient class referencing the server-side table
            TableClient tableClient = tableServiceClient.GetTableClient(
                tableName: "visitors"
            );

            await tableClient.CreateIfNotExistsAsync();

            try
            {
                TableEntity qVisitRow = await tableClient.GetEntityAsync<TableEntity>(partitionKey, rowKey);
                log.LogInformation("Found row, incrementing...");
                qVisitRow["VisitCounter"] = (int)qVisitRow["VisitCounter"] + 1;
                await tableClient.UpdateEntityAsync(qVisitRow, qVisitRow.ETag);
                string responseMessage = qVisitRow["VisitCounter"].ToString();
                return new OkObjectResult(responseMessage);
            }
            catch {
                log.LogInformation("Didn't find row, usperting...");
                await tableClient.UpsertEntityAsync(defaultRow);
                string responseMessage = defaultRow["VisitCounter"].ToString();
                return new OkObjectResult(responseMessage);
            }

        }


    }



}
