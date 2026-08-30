#!/bin/bash
LATEST_RUN=$(gh run list --workflow=deploy.yml -L 1 --json databaseId -q '.[0].databaseId')
while true; do
  STATUS=$(gh run view $LATEST_RUN --json status,conclusion -q '.status')
  CONCLUSION=$(gh run view $LATEST_RUN --json status,conclusion -q '.conclusion')
  if [ "$STATUS" = "completed" ]; then
    echo "Done! Conclusion: $CONCLUSION"
    break
  fi
  sleep 30
done
