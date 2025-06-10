package main

import (
  "github.com/gin-gonic/gin"
  "net/http"
  "io"
)

func main() {
  router := gin.Default()
  router.GET("/proxy", func(c *gin.Context) {
    target := c.Query("target")
    resp, err := http.Get(target)
    if err != nil {
      c.JSON(http.StatusInternalServerError, gin.H{"error": "Error when making the request"})
      return
    }
    defer resp.Body.Close()
    body, err := io.ReadAll(resp.Body)
    if err != nil {
      c.JSON(http.StatusInternalServerError, gin.H{"error": "Error when reading the response"})
      return
    }
    c.String(http.StatusOK, string(body))
  })
  router.Run()
}
